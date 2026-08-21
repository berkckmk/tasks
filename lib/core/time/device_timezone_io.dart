import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'iana_timezone.dart';

/// Matches the channel name handled in
/// `android/app/src/main/kotlin/.../MainActivity.kt`.
const MethodChannel _channel = MethodChannel('com.steadyprogress/device_info');

/// The device's IANA timezone id, or `'UTC'` if it can't be determined.
///
/// On Android this is `java.util.TimeZone.getDefault().id`, which is always a
/// real IANA id ("Europe/Istanbul"), unlike Dart's `timeZoneName`.
Future<String> resolveDeviceTimeZone() async {
  try {
    final id = await _channel.invokeMethod<String>('getTimeZoneId');
    if (id != null && isIanaTimeZone(id)) return id;
    debugPrint('Ignoring non-IANA timezone id from platform: $id');
  } catch (error) {
    debugPrint('Could not read the platform timezone: $error');
  }
  return 'UTC';
}
