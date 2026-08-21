import 'package:flutter_test/flutter_test.dart';
import 'package:steady_progress/core/time/iana_timezone.dart';

void main() {
  group('isIanaTimeZone', () {
    test('accepts real region zone ids', () {
      expect(isIanaTimeZone('Europe/Istanbul'), isTrue);
      expect(isIanaTimeZone('America/New_York'), isTrue);
      expect(isIanaTimeZone('Australia/Sydney'), isTrue);
      expect(isIanaTimeZone('America/Argentina/Buenos_Aires'), isTrue);
      expect(isIanaTimeZone('UTC'), isTrue);
    });

    // These are exactly what `DateTime.now().timeZoneName` returns, and the
    // reason this validator exists: the backend's Intl.DateTimeFormat throws
    // on each one and falls back to UTC, silently running every reminder,
    // digest and Calendar sync in the wrong zone.
    test('rejects the abbreviations DateTime.timeZoneName reports', () {
      expect(isIanaTimeZone('+03'), isFalse);
      expect(isIanaTimeZone('EDT'), isFalse);
      expect(isIanaTimeZone('CEST'), isFalse);
      expect(isIanaTimeZone('GMT+05:30'), isFalse);
      expect(isIanaTimeZone('Pacific Standard Time'), isFalse);
      expect(isIanaTimeZone(''), isFalse);
    });

    // 'EST' parses as a valid IANA id, but it's a fixed UTC-5 zone with no
    // DST — accepting it would leave a New York user an hour off all summer.
    test('rejects fixed-offset abbreviations that happen to be valid ids', () {
      expect(isIanaTimeZone('EST'), isFalse);
      expect(isIanaTimeZone('EET'), isFalse);
    });

    test('rejects malformed slash-separated values', () {
      expect(isIanaTimeZone('Europe/'), isFalse);
      expect(isIanaTimeZone('/Istanbul'), isFalse);
      expect(isIanaTimeZone('Europe / Istanbul'), isFalse);
    });
  });
}
