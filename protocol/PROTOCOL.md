# Tether link protocol, version 1

This is the contract between the Android app (BLE *peripheral*, holds the SIM)
and the iOS app (BLE *central*). Both implementations are tested against
`vectors.json` in this folder.

All integers are big-endian unless stated otherwise.

## 1. Bluetooth LE

| Item | UUID | Notes |
|---|---|---|
| Service | `5ABF5C3C-2BF1-4B1C-9E8E-5D153F835BD5` | Advertised (service UUID only, no name). |
| PSM characteristic | `6C0D1EB1-67F4-4181-9752-9CC90D6EFF88` | Read. Value: L2CAP PSM as `uint16` **little-endian**. |
| RX characteristic (fallback) | `214E1CD9-F397-4A0F-BB6C-ED1D8C7A38A5` | Write-without-response, central → peripheral. |
| TX characteristic (fallback) | `7BA52139-0888-4234-A49D-0271E0F2A647` | Notify, peripheral → central. |
| Wake characteristic | `9A3F1C52-7E0B-4D8A-B1E6-2C5D4F7A8E31` | Notify. The central always subscribes. The peripheral sends a 1-byte notification right before urgent traffic (ringing, call end, new SMS); a GATT notification reliably wakes a suspended iOS app, which then drains the L2CAP channel. |

**No link-layer security.** No characteristic or descriptor asks for encryption, the L2CAP channel is the
insecure kind, and nothing triggers Bluetooth pairing: the link is secured by Tether's own handshake and records
(§3–4), never by a bond. Until 2026-11-22 every characteristic required encryption; once the owner paired the phones
over classic Bluetooth for tethering, the Android phone held a derived LE key recorded with size 0 and iOS reached the GATT
service over the classic (BR/EDR) link, so every read failed "insufficient encryption key size". The Android phone checks its
service at start-up (`gattSecurity` in the state hook) and a unit test fails if an encrypted permission or the
secure L2CAP listener comes back. Trade-off: without a bond made by Tether, iOS may not follow the Android phone's rotating
address on its own; a bond made for anything else (tethering) still lets it, and the service-UUID scan reconnects
otherwise.

The primary transport is one L2CAP connection-oriented channel on the PSM.
Android's L2CAP channel is LE only: when iOS reaches the service over BR/EDR (the phones are also linked for
Bluetooth tethering), the channel cannot open and the GATT transport is used. A failed PSM read also goes straight
to the GATT transport.

The peripheral holds an LE link to its paired central (a GATT client connection) while a session is up, so iOS keeps
the session on LE and L2CAP even when the phones are also linked over classic Bluetooth, instead of moving GATT
between links and dropping the session. It never holds one otherwise: iOS does not complete an app's new connect
while an LE link to the peripheral exists. Without a session it pulses an LE link (up 3 s, only when no LE link
exists: every 5 s for a minute after a session ended, then every 30 s), because a link coming up completes the
central's waiting connect; and 3 s after an LE session ended without a new one it closes the idle connection iOS
keeps for a dead app. A GATT session ends when the
ACL it runs on goes or the central's LE link appears under a classic-link session; a pair-mode HELLO repeated by the
same central within 10 minutes of a completed pairing is accepted (it may have lost the FIN); a stream left mid-record
for 10 s ends the session on either side.
If the channel cannot be opened, the central falls back to GATT: RX writes and
TX notifications carry the *same byte stream* as the L2CAP channel, cut into
chunks of at most `ATT_MTU - 3` bytes. Chunk boundaries carry no meaning.

The central keeps a pending `connect` to the bonded peripheral at all times
(iOS state restoration), and also scans for the service UUID as a backup.
Neither side drops an idle session: a suspended iPhone may be silent for a long
time. Liveness comes from the BLE supervision timeout and L2CAP EOF; the
peripheral pings once a minute; after 15 minutes of silence it wakes the central (wake characteristic) and gives up
only if nothing arrives within 45 s more (a suspended iPhone answers once woken). The iPhone pings every 25 s
while it runs (the round trip is shown in its call statistics); while it is suspended its timers do not run.
During calls the peripheral asks for high connection priority and the 2M PHY (the state hook shows the PHY and the
connection parameters each link really got).

## 2. Records

The byte stream is a sequence of records:

```
+----------------+-----------+-----------------+
| len : uint16   | kind: u8  | body (len-1 B)  |
+----------------+-----------+-----------------+
```

`len` counts `kind` + `body`, so the largest body is 65534 bytes. Senders keep
plaintext payloads at or below 16 KiB; larger data is paged at the message
layer.

| kind | Name | Direction | Body |
|---|---|---|---|
| `0x01` | HELLO | C → P | see §3 |
| `0x02` | HELLO_ACK | P → C | see §3 |
| `0x03` | REJECT | P → C | `reason: u8` (1 = bad version, 2 = unknown device, 3 = pairing closed or token expired, 4 = busy) |
| `0x10` | SEALED | both | `ctr: u64` ‖ AES-256-GCM ciphertext ‖ 16-byte tag |

Any other kind closes the connection.

## 3. Handshake

Keys are NIST P-256. Public keys travel as 65-byte uncompressed X9.63 points
(`0x04 ‖ X ‖ Y`). ECDH output is the 32-byte X coordinate.

* `s_P` / `S_P`: the Android app's long-term (static) key pair.
* `s_C` / `S_C`: the iPhone's long-term key pair.
* `e_P`, `e_C`: fresh ephemeral key pairs, one per connection.

**Pairing QR code** (shown on the Android phone, valid 5 minutes, one use):

```
tether1:<base64url(S_P)>.<base64url(token)>.<base64url(utf8 device name)>
```

`token` is 16 random bytes. Base64url is without padding.

**HELLO** body (C → P), 148 bytes:

```
ver: u8 = 1 | mode: u8 (0 = resume, 1 = pair) | E_C: 65 | n_C: 16 | S_C: 65
```

**HELLO_ACK** body (P → C), 82 bytes:

```
ver: u8 = 1 | E_P: 65 | n_P: 16
```

In resume mode the peripheral sends REJECT 2 if `S_C` is not the stored
paired key. In pair mode it sends REJECT 3 unless a pairing token is open.

**Key schedule** (both sides):

```
dh1 = ECDH(e_C, E_P)          ephemeral-ephemeral (forward secrecy)
dh2 = ECDH(e_C, S_P)          proves the peripheral holds s_P
dh3 = ECDH(s_C, E_P)          proves the central holds s_C
psk = token (pair mode) or empty (resume mode)
th  = SHA-256("TETHER-HS-1" ‖ HELLO body ‖ HELLO_ACK body)
okm = HKDF-SHA256(salt = th, ikm = dh1 ‖ dh2 ‖ dh3 ‖ psk, info = "tether/1 keys", L = 64)
k_c2p = okm[0..32)    k_p2c = okm[32..64)
```

**Finish.** The central's first SEALED record (counter 0) has plaintext
`0xFF ‖ th`. The peripheral checks it (this authenticates the central and, in
pair mode, proves knowledge of the token), stores `S_C` if pairing, marks the
token used, and answers with its own SEALED record (counter 0) with plaintext
`0xFF ‖ th`. The central checks it. The session is then up.

## 4. Sealed records

```
nonce = 0x00000000 ‖ ctr (u64)        12 bytes
aad   = 0x10 ‖ ctr (u64)              9 bytes
key   = k_c2p (C → P) or k_p2c (P → C)
```

Each direction counts from 0 and adds 1 per record. The receiver requires
`ctr` to equal the next expected value exactly; anything else (replay, gap,
reorder, bad tag) closes the connection. A session never sends 2^32 records;
it reconnects instead.

Plaintext = `channel: u8` ‖ payload:

| channel | Payload |
|---|---|
| `0x00` | control message, UTF-8 JSON (§5) |
| `0x01` | audio frame: `codec: u8` (1 = Opus, 2 = G.711 µ-law) ‖ `seq: u16` ‖ frame bytes. 20 ms per frame. |
| `0xFF` | handshake finish (`th`) |

Audio is drop-late: the Android phone discards queued audio frames more than 60 ms old *before* sealing (so
counters stay contiguous). The receivers keep a playout / jitter buffer: the Android phone drops uplink frames whose
`seq` goes back (but follows a client whose counter restarted after 3 such frames) and conceals 1–2 missing
frames; the iPhone plays out from a 30–120 ms adaptive buffer whose depth follows the spread of frame arrival times over
the last ~10 s (around the far clock's rate), fills 1–2 lost frames with the Opus decoder's concealment, conceals
short gaps (the last 10 ms faded out) and drains clock drift in quiet frames. On the Android phone the uplink waits
in a buffer of up to 1 s whose delay is corrected in quiet frames (cut or repeated; speech sped up or slowed by
≤ 3 % only without a pause). `seq` keeps counting for the whole call.

## 5. Control messages

Envelope: `{"t": "<type>", "id": <int>?, "re": <int>?, "b": { ... }?}`.
`id` is set on requests that expect an answer; the answer carries `re`.
Unknown types are ignored. Times are Unix milliseconds. Phone numbers are as
stored on the Android phone.

| Type | Dir | Body |
|---|---|---|
| `ping` / `pong` | both | `{ts}` |
| `status` | P→C | `{device, battery, charging, sims:[{slot, sub, name, carrier, number?, signal, net?, service?, roaming?, country?}], defaultSub?, dialer, helper:{state, method?, up, down, silent?}, wifi, adbWifi, clients?:[{name, kind, self?, audio?}]}` (`clients`: every connected client; `self` marks the receiver, `audio` the one call audio goes to; per SIM: `signal` 0–4, `net` "5G" \| "LTE+" \| "LTE" \| "H+" \| "H" \| "3G" \| "E" \| "2G", `service` "in" \| "none" \| "emergency" \| "off", `roaming`, `country` the SIM's lowercase ISO 3166 code (else the network's; optional, for grouping national numbers on display). Pushed again within ~2 s of a signal / network change). Optional, from builds with the phone tools: `tools:{ussd, find, ringer}` (clients hide the matching controls when absent), `ringer` "normal" \| "vibrate" \| "silent", `dnd` (Do Not Disturb access granted) |
| `sync` | C→P | `{sms: lastId, calls: lastId, contacts: version, codecs: ["opus", "pcmu"], client?: {kind: "iphone" \| "android", name}}` (0 / "" for a full sync; `codecs` = what the client can decode/encode, best first; `client` names it in the Android phone's device list; `kind` "android" is the Android client, see §5.1) |
| `sms.batch` | P→C | `{items:[Sms], more}` |
| `sms.new` | P→C | `{item: Sms}` |
| `sms.send` | C→P | `{to, body, sub?}` → `sms.result` `{ok, state: "sent"\|"delivered"\|"failed", err?}` (may arrive twice: sent, then delivered) |
| `contacts.batch` | P→C | `{items:[Contact], more, version, full}` |
| `contact.star` | C→P | `{id, on}`: Favourites (the contact's starred flag) → `contact.result`; the contacts version changes |
| `contact.add` | C→P | `{name, phones:[{n, type, label?}], emails:[...]}` → `contact.result` `{ok, id?, err?}` (`label`: a custom kind such as "Satellite", stored as Android's custom type) |
| `contact.update` | C→P | `{id, name, phones:[{n, type, label?}], emails:[...]}`: replaces the contact's name, numbers and e-mail addresses → `contact.result` `{ok, id?, err?}`; the contacts version changes. Per number: a `label` sets the custom kind, `""` clears it (the number takes `type`), no `label` keeps an existing custom kind unless `type` changed (older clients never send labels) |
| `calls.batch` | P→C | `{items:[CallEntry], more}` |
| `call.state` | P→C | `Call` |
| `call.list` | P→C | `{calls:[Call]}` (sent after every handshake) |
| `call.answer` / `call.reject` / `call.end` | C→P | `{cid}` |
| `call.hold` | C→P | `{cid, on}` |
| `call.mute` | C→P | `{on}` |
| `call.dtmf` | C→P | `{cid, d}` (`0-9 * #`) |
| `call.dial` | C→P | `{num, sub?}` → `call.dialed` `{ok, err?}` |
| `call.take` | C→P | `{cid}`: move the call's audio to this client (see §5.1) |
| `audio.start` | P→C | `{codec: "opus"\|"pcmu", rate, ms, up, bitrate?}` (`bitrate`: what the Android phone encodes at; the client uses it for the uplink) |
| `audio.stop` | P→C | `{}` |
| `audio.stats` | P→C | `{summary, helper?}`: the Android phone's half of a call's audio statistics, sent ~0.5 s after `audio.stop` to the client that had the audio (`summary`: one line for its log; `helper`: the shell helper's figures). Optional, informational |
| `selftest` | C→P | `{}` → `selftest.result` `{methods:[{name, ok, note, delayMs?}], chosen?}` (`delayMs`: an inject method's measured delay into the call uplink) |
| `sms.read` | both | `{thread, upTo}`: read on a client; the Android phone marks it read and forwards it to the other clients |
| `sms.unread` | P→C | `{ids:[id], all}`: the Android phone's unread incoming texts, after every sync and within ~2 s of a read-state change there; everything else is read (`all` false: list capped at 3000, only ids ≥ its smallest are known) |
| `sms.delete` | C→P | `{ids?:[id], thread?}` → `sms.deleted` `{ok, ids:[id], thread?, err?}` to the asking client (with `re`) and to every other client (see §5.2) |
| `calls.delete` | C→P | `{ids?:[id], all?}` → `calls.deleted` `{ok, ids, all?, err?}` to all clients |
| `lists.set` | C→P | `{what: "block", num, on}` \| `{what: "mute", thread, on}` → `lists` to all clients |
| `lists` | P→C | `{blocked:[num], muted:[thread], system, err?}` (also after every sync; `system`: Android's own block list is used) |
| `sync.ids` | P→C | `{sms:[[first,last]…], calls:[[first,last]…], more?}` after every sync: ids that still exist (inclusive ranges); split into pages with `more: true` when very long, applied once the last page is in |
| `net.get` / `net.set` | C→P | `{}` / `{what, on, sub?}` → `net.state` (see §5.3) |
| `ussd.send` / `ussd.result` | C→P / P→C | `{code, sub?}` (code matches `^[*#][0-9*#]{1,30}#$`, else refused) → `{ok, text?, err?}` (`re` = the request; sent on SIM `sub` through `TelephonyManager.sendUssdRequest`, 30 s timeout; one at a time; a test client is never sent to the network) |
| `phone.find` / `phone.finding` | C→P / P→C | `{on}` → `{on, err?}`: the Android phone rings on the alarm stream at maximum alarm volume for at most 30 s (volume restored afterwards; stops on `on:false`, the notification's Stop action or a screen unlock). `phone.finding` is also pushed to every client when it starts or stops |
| `ringer.set` / `ringer.result` | C→P / P→C | `{mode: "normal"\|"vibrate"\|"silent"}` → `{ok, mode, err?}` (`err` e.g. Do Not Disturb access missing for silent); `status` then carries the new `ringer` |
| `unpair` | C→P | `{}` (peripheral forgets `S_C`) |
| `error` | both | `{msg}` |

Objects:

```
Sms       {id, thread, addr, body, date, box, read, sub?}
          box: 1 inbox, 2 sent, 3 draft, 4 outbox, 5 failed, 6 queued
Contact   {id, name, phones:[{n, type, label?}], emails:[...], photo?(base64 JPEG ≤ 96 px), starred}
          type: "mobile" | "home" | "work" | "main" | "other"
CallEntry {id, num, name?, date, dur, type, sub?}
          type: 1 incoming, 2 outgoing, 3 missed, 4 voicemail, 5 rejected, 6 blocked
Call      {cid, num, name?, state, dir, sub?, since?, cause?, hold, elsewhere?, where?}
          state: "ringing" | "dialing" | "connecting" | "active" | "holding" | "ended"
          dir: "in" | "out"; hold: whether hold is supported
          elsewhere: the call's audio is on another client, named by `where` (per receiver, see §5.1)
```

### 5.1 Several clients

The Android phone accepts more than one client (it did serve an iPhone and a Mac at once until the Mac client was removed
on 2026-11-22). Today's clients are the iPhone app (`kind` "iphone") and the Android client (`kind` "android", a second
Android phone running `android/client`). The rules below stay in force.

Only an iPhone gets the held / pulsed LE link of §1 and has its address remembered for it: an Android client keeps
its own connection (it reconnects by scanning for the service) and is not woken by a pulse. A client paired in the
current session has no kind until its first `sync`, so the Android phone decides this at that sync, never at the
handshake.

The peripheral keeps a list of paired clients (static keys + names) and accepts one link per client at
the same time; a client reconnecting replaces only its own old link. Pairing a new client never forgets
the others. Messages, call-log rows, status and call events go to every connected client.

Call audio has exactly one **owner**:
- the client that sends `call.answer` or `call.dial` for the call, or `call.take` later;
- if nobody claimed it (answered on the Android phone itself): the client used most recently, else the iPhone.

`audio.start` / `audio.stop` and audio frames go to the owner only; audio frames from other clients are
ignored. Every `call.state` is sent per client: for non-owners, an answered / dialing / held call carries
`elsewhere: true, where: <owner name>`. A client that receives `elsewhere` ends its local ringing or call
(CallKit reason *answered elsewhere*) and offers **Move here**, which sends `call.take`. On a change of
owner the peripheral sends `audio.stop` to the old owner, `audio.start` to the new one, and the current
state of every call to all clients.

### 5.2 Delete, block, mute

The Android phone is the source of truth. A client asks (`sms.delete`, `calls.delete`, `lists.set`), removes the
items or updates its lists at once, and the Android phone answers every connected client, so the other client
follows live (and clears its delivered notifications of deleted or muted conversations). A client that
was away learns deletions on its next sync from `sync.ids`: every local row with a positive id outside
those ranges is gone (local placeholders of texts being sent have negative ids and are kept).

Blocking writes Android's block list (`BlockedNumberContract`, allowed for the default phone app) and
mirrors it in Tether's own list. Android then refuses blocked calls and texts itself; Tether also rejects
blocked callers in its call screening / in-call service and does not forward texts from blocked senders,
so nothing from them reaches the iPhone even if the system list is unavailable. Muted
conversations are kept on the Android phone by thread id; clients show no notification for them. Deleting a
conversation also unmutes its thread id.

### 5.3 Network switches, airplane mode, network mode, Share VPN

`net.set {what, on, sub?, slot?, mode?}`, `what` ∈ `data`, `hotspot`, `bt`, `dataSub` (with `sub`), `airplane`,
`rat` (with `slot` 0/1 and `mode` "5G" | "4G" | "3G" | "2G": every technology up to that one, like the phone's
"auto connect" modes), `share`.
`net.state`: `{data, hotspot, bt, dataSub, vpn, airplane, rat:[{slot, mode}], share, proxy: {port, addrs:[{iface,
ip, kind: "hotspot"|"bt"|"usb", pac}]}, err?}`. `vpn` is read-only (a VPN is up on the Android phone; it is switched in the
VPN app). A `net.state` caused by `share` or `airplane` is also sent to the other clients (without `re`).

Airplane mode keeps Bluetooth on. If no client has been linked for 90 s while airplane mode (switched on from a
client) is on, the Android phone switches it off by itself; the hotspot / Bluetooth tethering that were on before come back.

The proxy at `ip:port` speaks HTTP (absolute-form requests), HTTPS via `CONNECT`, SOCKS5 (no auth, CONNECT) and
serves `GET /proxy.pac`.

## 6. Shell helper socket (Android-internal)

The helper (`app_process`, uid 2000) is started with
`HelperMain serve <port> <token>` and listens on `127.0.0.1:<port>`; the app
connects to it. (SELinux denies the shell domain `connectto` on an app's Unix
socket, so the helper must be the listener.) `<token>` is random and new for every
launch; it never crosses the socket. Mutual challenge-response (helper version 3):

1. Helper → app: CHALLENGE with 16 random bytes `h`.
2. App → helper: AUTH with 16 random bytes `a` ‖ HMAC-SHA256(token, "tether-helper app" ‖ h ‖ a).
3. Helper → app: PROOF = HMAC-SHA256(token, "tether-helper helper" ‖ a ‖ h). The app sends nothing else to a
   listener that does not send a valid PROOF (an app that took the port first gets neither the token nor audio).
4. Helper → app: HELLO; then the frames below. Each connection authenticates on its own thread (2 s limit); an
   authenticated connection replaces the previous one. At most 4 connections authenticate at once (more are closed);
   each launch has a new port and token. Frames are at most 1 MiB.

Frames: `type: u8 ‖ len: u32 ‖ payload`.

| type | Dir | Payload |
|---|---|---|
| 1 HELLO | H→A | JSON `{pid, uid, sdk, version, apk}` (`apk`: the helper's class path; a different one means a stale helper, relaunched) |
| 2 START | A→H | JSON `{rate, capture, inject, injectMs?}` (`auto` tries every method in order; `injectMs`: cap of the uplink playback buffer, default 40) |
| 3 STOP | A→H | – |
| 4 DOWN | H→A | PCM 16-bit LE mono, 20 ms |
| 5 UP | A→H | PCM 16-bit LE mono, 20 ms |
| 6 INFO | H→A | JSON `{capture, inject, method, earpiece, silent, silence, telecomMicMute, error?}` (`silence`: how the phone's own earpiece / mic are silenced: samsung, qualcomm, mediatek, other; `silent`: full, earpiece, none; `telecomMicMute` false: the app must not mute the mic through Telecom), or `{stats}` at stop; replies `{probe}`, `{selftest}`, `{net}` (a reply after its request timed out is dropped) |
| 7 PROBE | A→H | – (answers INFO `{probe: …}`) |
| 8 QUIT | A→H | – (helper exits) |
| 9 SELFTEST | A→H | – (answers INFO `{selftest: …}`; needs a live call) |
| 11 NET | A→H | JSON `{what?, on?, sub?, …}` (network switches; no `what` only reads; answers INFO `{net: …}`) |
| 10 AUTH | A→H | 16-byte nonce ‖ 32-byte HMAC (see above) |
| 12 CHALLENGE | H→A | 16-byte nonce |
| 14 PROOF | H→A | 32-byte HMAC |
