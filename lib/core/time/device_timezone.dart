/// Resolves the device's IANA timezone identifier (e.g. `Europe/Istanbul`).
///
/// This exists because `DateTime.now().timeZoneName` does NOT return one.
/// It returns whatever short abbreviation the host platform reports —
/// `"+03"` in Turkey, `"EDT"`/`"CEST"` in summer, `"GMT+05:30"` in India.
/// None of those are IANA zone ids, and the backend
/// (`functions/src/lib/datetime.ts`) feeds this value straight into
/// `Intl.DateTimeFormat`, which throws on anything it doesn't recognise —
/// so `safeTimeZone()` silently swapped it for `"UTC"`.
///
/// The effect was that every timezone-aware backend feature quietly ran in
/// UTC: habit reminders fired at the wrong hour, the 08:00 daily digest
/// arrived at 08:00 UTC, and synced Calendar events were stamped `UTC`.
/// Nothing errored anywhere, which is what made it hard to see.
///
/// Worse, it was intermittent by season: `"EST"` happens to be a real (fixed,
/// DST-less) IANA zone, so a US-Eastern user's reminders worked in winter and
/// broke in summer, when the platform starts reporting `"EDT"` instead.
library;

export 'device_timezone_io.dart'
    if (dart.library.js_interop) 'device_timezone_web.dart';
