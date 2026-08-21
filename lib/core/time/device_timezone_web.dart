import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;

import 'iana_timezone.dart';

/// `Intl.DateTimeFormat().resolvedOptions().timeZone` — the browser's own
/// resolved IANA zone id. Supported in every browser Flutter web targets.
@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

/// The browser's IANA timezone id, or `'UTC'` if it can't be determined.
Future<String> resolveDeviceTimeZone() async {
  try {
    final id = _DateTimeFormat().resolvedOptions().timeZone;
    if (id != null && isIanaTimeZone(id)) return id;
    debugPrint('Ignoring non-IANA timezone id from the browser: $id');
  } catch (error) {
    debugPrint('Could not read the browser timezone: $error');
  }
  return 'UTC';
}
