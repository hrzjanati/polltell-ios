# Troubleshooting

Start with the logs: on the iPhone, **Link › Link log**; on the Android phone, with USB debugging,
`tools/dbg.sh linklog`. They show every connect, drop (with Bluetooth's reason code) and setup step.

## The iPhone does not link

| Symptom | What to do |
| --- | --- |
| Link tab says *Searching* for a long time | Bluetooth on both phones; the Android phone's Tether notification should say *Advertising, waiting for iPhone*. If it says *Bluetooth off* or nothing, open Tether on the Android phone once |
| "The Android phone does not recognise this iPhone" | The pairing was removed on the Android phone: pair again (SETUP.md step 2) |
| "Pairing code expired" | The QR code is valid for 5 minutes and once only, and is lost if Tether restarts: tap Pair iPhone again for a new one |
| Links, then drops every few seconds | Check the link logs for the reason. Battery savers: give Tether unrestricted battery use on Android |
| Nothing after an update of the Android app | Open Tether on the Android phone once (some phones do not restart its service after an update) |

### Bluetooth tethering

Bluetooth tethering pairs the two phones over classic Bluetooth. iOS then runs Tether's GATT connection over that
classic link whenever it is the only one, where Tether's fast L2CAP channel cannot open, and moves it to Bluetooth LE
as soon as an LE link appears, which ends the session running at that moment. To keep one stable session, the Android
app holds an LE link to the iPhone while a session is up (link log: *LE link held*), so iOS keeps it on LE and
L2CAP and nothing moves underneath it. If a session does start over the classic link, the first LE link ends it
once and the iPhone sets up again over LE within seconds.

Tether never uses Bluetooth's own encryption or pairing, so the pairing made for tethering cannot break it. Older
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
  "Calls paused" notification as it closes. Leave Tether in the background instead of swiping it away; it uses
  almost no battery while it waits.
- **Stopped by iOS** in the background (low memory): iOS starts it again when the Android phone brings a Bluetooth
  link up, which it tries every 5 s for a minute after the link was lost, then every 30 s. Usually seconds, but
  not guaranteed: open the app if calls stop arriving.
- **In the background**: the session stays up; nothing to do.

## No call audio

On Android 10 the phone cannot bridge call audio at all, and on Android 11 and 12 it works only if the phone's audio
system allows capturing the call: see [features by Android version](devices/android-versions.md). The Call audio
card in the Android app says which case you are in.

1. In Tether on the Android phone, the **Audio helper** must say *Running*. If not, see the next section.
2. During a call, tap **Run call-audio self-test**: it lists each capture and inject path and whether it works.
3. The Android version must be 13 or later, and the build must let the shell user intercept call audio. Not every
   manufacturer allows it. If no path works, calls still work from the iPhone but their audio stays on the
   Android phone. Please report your model and the self-test result.
4. You hear the other side on the Android phone too: Tether mutes the phone's own earpiece and microphone during a
   bridged call with each vendor's controls: Samsung (tested), Qualcomm and MediaTek (from their audio sources,
   untested). Other phones (Google Pixel and unknown chips) get the earpiece muted only. The Link tab shows it
   under **Call audio › Android phone silent**. On MediaTek, Tether never mutes the microphone through Android,
   because there that also mutes what the iPhone sends.

### Headset or car

- The call does not go to the headset or car: it must be connected as a hands-free (calls) device in the iPhone's
  Bluetooth settings; music-only (A2DP) speakers have no microphone and are not offered for calls.
- The Link log shows each route change as `audio route bluetooth / car / receiver / speaker` with its reason. If
  the route changes but the far end goes quiet for more than a second, please report the lines around it.

## The audio helper does not start

- Wireless debugging needs a Wi-Fi connection when the helper starts. Connect the Android phone to Wi-Fi, then tap
  **Start**.
- With TCP debugging (SETUP.md): the TCP mode is lost on every phone restart; connect USB and run `adb tcpip 5555`
  again, accept the key prompt, then tap **Start**. If you used another port, Tether only tries the one it was
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
