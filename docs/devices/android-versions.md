# Features by Android version

Tether installs on Android 10 (API 29) and later. What works depends on the version, mostly because the shell user
(which the audio helper runs as) is given more permissions by newer Android releases. Only the Samsung Galaxy A54 on
Android 17 has been tested; the other rows follow from the Android sources and API levels, and are expected, not tried.

| Feature | Android 10 | Android 11-12 | Android 13+ |
| --- | --- | --- | --- |
| Link to the iPhone (L2CAP, GATT fallback), pairing | yes | yes | yes |
| Messages, contacts, call log, notifications | yes | yes | yes |
| Answering, placing and ending calls from the iPhone | yes | yes | yes |
| Call audio on the iPhone | **no** (the shell cannot capture a call) | best effort: captures the voice call, injects through the incall-music path (`voice_downlink` / `voice_call`, `telephony_tx`); works only where the phone's audio HAL allows it | yes: call-audio interception API, older routes as fallback |
| Muting the phone's own earpiece and microphone during a bridged call | Samsung only | Samsung only | Samsung only |
| Audio helper (mobile data, data SIM, airplane mode, network mode) | needs the TCP adb path (see [SETUP.md](../SETUP.md)); hotspot and Bluetooth tethering switches are not available | yes | yes |
| Wireless debugging pairing | not in Android 10: use TCP adb | yes (needs a Wi-Fi network) | yes |
| Hotspot and Bluetooth tethering switches | no | yes | yes |
| Signal and network type per SIM | yes (network type from the plain data type) | yes | yes |
| SIM phone number in the status | from the SIM record, often empty | from the SIM record | from the subscription service |
| Call notification | plain notification with buttons | plain with buttons (11) / call style (12) | call style |

Notes:

- Below Android 12 the Bluetooth runtime permissions do not exist; Tether uses the install-time Bluetooth
  permissions. Android 13 added the notification permission.
- On Android 10 a call's SIM is found by the SIM's card id; if the phone does not expose it, the SIM choice for
  placing a call may fall back to the default.
- The app, the helper and `./gradlew :app:lintRelease :helper:lintRelease` treat calls to newer APIs without a version
  check as errors, so a regression shows up in the build.
