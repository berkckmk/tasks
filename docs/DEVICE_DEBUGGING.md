# Running on a physical Android device

Written against a Galaxy S25 (SM-S931B, Android 16 / API 36) over wireless adb.
Most of this is Samsung-specific but the failure modes generalise.

## Wireless debugging drops are a power-management problem

The symptom looks like a Flutter bug and is not:

```
Error connecting to the service protocol: failed to connect to http://127.0.0.1:PORT/…
HttpException: Connection closed before full header was received
```

or, mid-session:

```
Lost connection to device.
```

The APK installs fine and then the attach fails, or the session dies minutes in.
`adb devices` shows the device as `offline`.

**Cause:** Samsung power saving throttles the WiFi radio, which kills the adb
tunnel *and* the app's own DNS. The tell is Firestore failing at the same
moment with `android_getaddrinfo failed: EAI_NODATA` — that is the phone's
network stack going away, not a socket problem.

**Fix:**

```bash
D=<ip>:5555
adb -s $D shell settings put global low_power 0
adb -s $D shell dumpsys deviceidle disable
```

After this, a session that had been dying within minutes held 300s+ with no
drop, and LAN ping jitter fell from 82ms average to 31ms.

**`svc power stayon true` does not help on its own.** It sets
`stay_on_while_plugged_in`, which only applies *while charging*. On battery it
is inert. Keeping the phone plugged in is the durable fix; on battery the drops
return as the charge falls, because Samsung re-enables power saving.

Check the state with:

```bash
adb -s $D shell dumpsys battery | grep -iE 'AC powered|USB powered|level'
adb -s $D shell settings get global low_power
adb -s $D shell settings get system screen_off_timeout
```

## Reconnecting

```bash
adb disconnect <ip>:5555 && adb connect <ip>:5555
```

Do this first whenever anything reports `device offline`; it is almost always
enough, and a failed `flutter run` after it will usually succeed.

## Prefer adb over `flutter run` on a flaky link

`flutter run` couples build, install, launch and the VM-service attach. On an
unstable connection the attach is what breaks, and it takes the whole session
with it even though the app installed correctly. Decoupling is more robust:

```bash
flutter build apk --debug
adb -s $D install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s $D shell am start -n com.steadyprogress.steady_progress/.MainActivity
adb -s $D logcat -d -s flutter          # read Dart output here
```

You lose hot reload, but you get deterministic install/launch and `debugPrint`
output still arrives via logcat. For a script that just needs to *run* something
on device — a seeder, a one-off check — this is the better shape.

Note also that a backgrounded `flutter run` cannot receive keystrokes, so `r`
and `R` are unavailable; hot reload needs an interactive terminal.

## Alternate entrypoints

`flutter run -t lib/debug/seed_main.dart` builds the same app package with a
different `main()`. Auth persistence is per-package, so whatever account is
signed in in the real app is signed in there too — useful for scripts that must
act as the user. It replaces the installed app, so the normal build has to be
reinstalled afterwards.

## Screenshots and UI driving

```bash
adb -s $D exec-out screencap -p > shot.png
adb -s $D shell input tap <x> <y>          # device pixels, e.g. 1080x2340
adb -s $D shell input keyevent KEYCODE_HOME
```

Screenshots are the only reliable way to check rendering that depends on the
real compositor — the home-screen widget especially, since it draws into the
launcher's process. Sampling pixels out of them with PIL is how the widget's
edge was calibrated against One UI (see `ANDROID_WIDGET.md`).

## Turn wireless debugging off when you are done

```bash
adb -s $D shell settings get global adb_wifi_enabled   # 1 = on
```

Unlike classic `adb tcpip`, the Android 11+ wireless debugging toggle **persists
across reboots**. Leaving it on is a standing exposure on a personal phone —
adb access bypasses the permission model entirely (`run-as` on any debuggable
app, install, logcat, `input tap`). Turn it off in Developer options →
Wireless debugging. See `ANDROID_SECURITY_POSTURE.md`.
