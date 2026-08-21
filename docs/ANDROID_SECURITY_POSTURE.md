# Android security posture

What this app can and cannot do on a user's device. Complements
`SECURITY_REVIEW.md`, which covers the backend axis (plan enforcement, billing,
Firestore rules) and explicitly excludes the device side.

Assessed 2026-08-15 against the **merged** manifest read out of the built APK,
not the source manifest — plugins contribute permissions, and only the merged
result reflects what actually ships.

```bash
AAPT=~/Library/Android/sdk/build-tools/36.0.0/aapt2
$AAPT dump permissions build/app/outputs/flutter-apk/app-debug.apk
$AAPT dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-debug.apk
```

## Permissions actually shipped

| Permission | Source |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | app |
| `POST_NOTIFICATIONS` | app (runtime, user-granted) |
| `WAKE_LOCK`, `c2dm.permission.RECEIVE` | FCM |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | transitive; lets the app prompt for *its own* biometric auth, nothing more |
| `com.android.vending.BILLING` | `in_app_purchase` |
| `BIND_GET_INSTALL_REFERRER_SERVICE`, `READ_GSERVICES` | Play / GMS |
| `AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION` | `firebase_analytics` |

## What is deliberately absent

These are the permissions that make Android banking malware possible. None are
present, and without them the sandbox forbids reaching another app's data:

| Permission | Would enable |
|---|---|
| `SYSTEM_ALERT_WINDOW` | Drawing a fake login over another app (overlay / tapjacking) |
| `BIND_ACCESSIBILITY_SERVICE` | Reading any screen, synthesising taps |
| `READ_SMS` / `RECEIVE_SMS` | Intercepting one-time passcodes |
| `QUERY_ALL_PACKAGES` | Enumerating which banking apps are installed |
| `REQUEST_INSTALL_PACKAGES` | Side-loading a payload |
| `PACKAGE_USAGE_STATS` | Detecting which app is in the foreground |

Also absent: camera, microphone, location, contacts, phone state, external
storage.

`usesCleartextTraffic` is unset and `targetSdk` is 36, so cleartext HTTP is
blocked by default. `allowBackup` is unset, which means it **defaults to
`true`** — app data participates in Android cloud backup.

## Exported components

Eight, all standard:

| Component | Why exported |
|---|---|
| `MainActivity` | Launcher entry |
| `SteadyProgressWidgetConfigureActivity` | The launcher invokes it for widget setup |
| `FlutterFirebaseMessagingReceiver`, `FirebaseInstanceIdReceiver` | FCM; signature-permission protected |
| `GenericIdpActivity`, `RecaptchaActivity` | Firebase Auth OAuth redirects |
| `RevocationBoundService` | Google Sign-In |
| `ProfileInstallReceiver` | AndroidX baseline profiles |

The widget configure activity is reachable by other apps with an arbitrary
`appWidgetId`, which is the standard pattern for configure activities. Worst
case is altering this app's own widget appearance; it exposes no data.

`SteadyProgressWidgetProvider` itself is `exported="false"` and still receives
`APPWIDGET_UPDATE` because the system targets the component explicitly, and the
field-cycling broadcast is a self-targeted `PendingIntent` carrying the app's
own identity.

## The real exposure is the debug setup, not the app

Two things matter far more than anything above on a phone that is also used for
banking:

1. **Wireless debugging persists across reboots.** With `adb_wifi_enabled = 1`
   the phone listens for adb connections. Connecting requires RSA key
   authorisation, but "always allow from this computer" plus a compromised
   laptop, or an untrusted network, is a real path in. adb access bypasses the
   permission model wholesale: `run-as` on any debuggable app, install, logcat,
   screencap, and `input tap` to drive the UI. Turn it off when not actively
   debugging — see `DEVICE_DEBUGGING.md`.

2. **Debug builds are `debuggable=true`**, so `adb shell run-as
   com.steadyprogress.steady_progress` reads the app's private data — its
   Firestore cache and auth session included. This was used deliberately during
   development to repair widget preferences. Harmless alone; it compounds (1).
   A release build is the right thing to leave installed on a daily-driver
   phone.

## Optional hardening

Neither is a security defect; both are hygiene, and both are one-line changes.

- **Drop the advertising-ID permissions.** There are no ads. Add to
  `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="com.google.android.gms.permission.AD_ID"
      tools:node="remove" />
  ```
- **Disable cloud backup** if the local Firestore cache should not leave the
  device: `android:allowBackup="false"` on `<application>`.

## Release build checklist

`android/app/build.gradle.kts` falls back to the **debug** signing key when
`android/key.properties` is absent, so `flutter run --release` works locally but
produces an artefact Play Console will reject. `isMinifyEnabled = true` is set
for release. Confirm the signing config before treating any release build as
shippable.
