# Troubleshooting

Start with the logs: on the iPhone, **Link › Link log**; on the Android phone, with USB debugging,
`tools/dbg.sh linklog`. They show every connect, drop (with Bluetooth's reason code) and setup step.

## The iPhone does not link

| Symptom | What to do |
| --- | --- |
| Link tab says *Searching* for a long time | Bluetooth on both phones; the Android phone's PolTell notification should say *Advertising, waiting for iPhone*. If it says *Bluetooth off* or nothing, open PolTell on the Android phone once |
| "The Android phone does not recognise this iPhone" | The pairing was removed on the Android phone: pair again (SETUP.md step 2) |
| "Pairing code expired" | The QR code is valid for 5 minutes and once only, and is lost if PolTell restarts: tap Pair iPhone again for a new one |
| Links, then drops every few seconds | Check the link logs for the reason. Battery savers: give PolTell unrestricted battery use on Android |
| Nothing after an update of the Android app | Open PolTell on the Android phone once (some phones do not restart its service after an update) |

### Bluetooth tethering

Bluetooth tethering pairs the two phones over classic Bluetooth. iOS then runs PolTell's GATT connection over that
classic link whenever it is the only one, where PolTell's fast L2CAP channel cannot open, and moves it to Bluetooth LE
as soon as an LE link appears, which ends the session running at that moment. To keep one stable session, the Android
app holds an LE link to the iPhone while a session is up (link log: *LE link held*), so iOS keeps it on LE and
L2CAP and nothing moves underneath it. If a session does start over the classic link, the first LE link ends it
once and the iPhone sets up again over LE within seconds.

PolTell never uses Bluetooth's own encryption or pairing, so the pairing made for tethering cannot break it. Older
versions failed in this setup with *"PSM read failed: the encryption key size is insufficient"*, or connected and
dropped over and over: update both apps.

If it still drops while tethering, send both link logs (each session ends with a line saying its transport, how long
it lasted and why it ended) and use the **Wi-Fi hotspot** instead of Bluetooth tethering meanwhile: it does not
touch Bluetooth at all and is faster.

### After closing the app

- **Opened again**: the app links within a few seconds (about 1-3 s in tests): it starts a fresh connect every time
  it comes to the foreground.
- **Swiped away in the app switcher** (force quit): iOS does not start the app again for Bluetooth until you open
  it yourself, so calls and texts do not reach the iPhone meanwhile (calls still ring on the Android phone, and
  show on the iPhone as missed once it links). No app can change this. When iOS lets it, the app posts a
  "Calls paused" notification as it closes. Leave PolTell in the background instead of swiping it away; it uses
  almost no battery while it waits.
- **Stopped by iOS** in the background (low memory): iOS starts it again when the Android phone brings a Bluetooth
  link up, which it tries every 5 s for a minute after the link was lost, then every 30 s. Usually seconds, but
  not guaranteed: open the app if calls stop arriving.
- **In the background**: the session stays up; nothing to do.

## No call audio

On Android 10 the phone cannot bridge call audio at all, and on Android 11 and 12 it works only if the phone's audio
system allows capturing the call: see [features by Android version](devices/android-versions.md). The Call audio
card in the Android app says which case you are in.

1. In PolTell on the Android phone, the **Audio helper** must say *Running*. If not, see the next section.
2. During a call, tap **Run call-audio self-test**: it lists each capture and inject path and whether it works.
3. The Android version must be 13 or later, and the build must let the shell user intercept call audio. Not every
   manufacturer allows it. If no path works, calls still work from the iPhone but their audio stays on the
   Android phone. Please report your model and the self-test result.
4. You hear the other side on the Android phone too: PolTell silences the phone's own earpiece during a bridged call
   with each vendor's controls: Samsung (tested), Qualcomm and MediaTek (from their audio sources, untested), the
   voice-call volume on other phones. The phone's own **microphone stays on** unless you turn on **Mute this phone's
   microphone during bridged calls** (see the next section for why). The Link tab shows it under **Call audio ›
   Android phone silent**.

### Headset or car

- The call does not go to the headset or car: it must be connected as a hands-free (calls) device in the iPhone's
  Bluetooth settings; music-only (A2DP) speakers have no microphone and are not offered for calls.
- The Link log shows each route change as `audio route bluetooth / car / receiver / speaker` with its reason. If
  the route changes but the far end goes quiet for more than a second, please report the lines around it.

## The other side cannot hear me

You hear the other side, but they hear nothing (or only the Android phone's surroundings) of what you say on the
iPhone. The iPhone's voice is injected into the call's uplink by the Android phone. Things that can stop it:

- **The injection did not open.** Some phones refuse it, or refuse it until the call is fully connected.
- **The redirect audio mode on a phone that mishandles it.** By default (**This phone's microphone during bridged
  calls: Off during calls**, Android app › Call audio, or the picker in the iPhone's Link tab) PolTell puts the call in
  Android's redirect audio mode (Android 13+), in which the phone's own microphone and earpiece leave the call. PolTell
  checks every call: when the downlink goes silent in that mode, or your speech stops reaching the uplink, it gives
  the call its own mode back and remembers that for the phone model; the next calls try the next mode or keep the
  microphone on. Some phones cannot show their uplink to this check: there PolTell keeps the mode once nothing else went
  wrong.
- **The Android phone's microphone mute** (only with **Muted**). On several phones (MediaTek for certain, Qualcomm
  audio systems, possibly Samsung's own key) muting the phone's microphone also mutes the injected voice. PolTell
  checks during each call, turns the mute off when your voice does not get through and remembers it.
- **The iPhone sends silence**: PolTell may not use the iPhone's microphone (Settings › Privacy & Security ›
  Microphone; the Link tab warns in red), or the call is muted on the iPhone.

With **On** the Android phone's own microphone stays in the call: the other side may hear your voice twice (the
phone in the room hears you too), the bag's noise, and their own voice from the iPhone's speaker. **Off during
calls** avoids that where the phone allows it.

What to do:

1. Make sure the setting is **Off during calls** (the default) and call again. If the other side still hears
   nothing, try **On**: if that helps, please report it (step 4).
2. During a call, on the iPhone: **Link › Call audio › Run call-audio self-test** (or the same button in the Android
   app). It pauses the call audio for a few seconds and plays tones the other side may hear. Its rows:
   - `call-audio`: how your call ran until then: the inject and capture methods (`NONE` when the injection did not
     open) and what the phone's microphone did (out of the call in which mode, muted, or on).
   - `inject:<method>`: a tone through each inject method, listened for in the call's uplink.
   - `mic:call_redirect` (and `mic:call_screening` where the phone declares it): the phone's microphone level, the
     tone and the downlink without and with that mode, and a verdict: `ok` (the microphone left the call, or the tone
     still gets through), `no-effect` (the microphone stays in the call), `breaks-uplink` / `breaks-downlink` (a
     direction went silent), `refused`, `unverified` (this phone shows neither). PolTell remembers it for the model.
   - `inject:<method>, phone mic muted`: the working method once more with the microphone muted.
3. Open **Link › Link log** on the iPhone (or `tools/dbg.sh linklog` on the Android phone). Each call writes a line
   starting `call audio path:` (whether the uplink injection opened, with which method, what the microphone does),
   `call audio: call_redirect on` / `reverted` lines when the mode changed (with the reason), `uplink check …` lines,
   `remembered for this phone …` when a result was stored, and a `call audio:` summary at the end with the uplink
   figures (`uplink speech N frames`: 0 means the iPhone sent only silence).
4. Report it (GitHub issue) with: the Android phone's model and Android version, the iPhone model and iOS version,
   the microphone setting, every self-test row (name, ✓ / ✗ and its note), and the `call audio path:`,
   `call audio: …` and `uplink check` lines of one failed call. Leave out phone numbers.

## The audio helper does not start

- Wireless debugging needs a Wi-Fi connection when the helper starts. Connect the Android phone to Wi-Fi, then tap
  **Start**.
- With TCP debugging (SETUP.md): the TCP mode is lost on every phone restart; connect USB and run `adb tcpip 5555`
  again, accept the key prompt, then tap **Start**. If you used another port, PolTell only tries the one it was
  enabled with (default 5555).
- If the phone forgot the Wireless debugging pairing (some updates do), pair again (SETUP.md, Wireless debugging).
- From a computer, `tools/start-helper.sh` starts the helper over USB `adb` as a fallback.

## The iPhone app stopped opening

Apps signed with a free Apple account stop after 7 days. Run `tools/reinstall-ios.sh` again; your data and pairing
are kept. The Link tab shows how many days are left.

## Messages or calls are missing

Pull down to refresh in Messages, Recents or Contacts (syncs again with the Android phone). Texts deleted on the
Android phone disappear from the iPhone at the next sync.

## What to include in a report

- Phone models, Android and iOS versions, whether Bluetooth tethering was on.
- The iPhone's Link log and the output of `tools/dbg.sh linklog` (they contain no message text; check them for
  anything you do not want to share before posting).
- For audio problems: the self-test result.
