/// A cheap sanity check that [value] looks like an IANA zone id rather than
/// an abbreviation or a UTC offset.
///
/// Region ids are `Area/Location` (`Europe/Istanbul`, `America/New_York`,
/// `America/Argentina/Buenos_Aires`); the only zone worth accepting without a
/// slash is `UTC` itself.
///
/// That rejects exactly the values that caused the bug this directory exists
/// for — `+03`, `EDT`, `CEST`, `GMT+05:30` — and deliberately also rejects
/// `EST`, which *is* a valid IANA id but a fixed-offset one with no DST: a
/// New York device reporting `EST` in winter would be stranded an hour off
/// for the whole summer.
bool isIanaTimeZone(String value) {
  if (value == 'UTC') return true;
  if (value.contains(' ')) return false;
  final parts = value.split('/');
  if (parts.length < 2) return false;
  return parts.every((part) => part.isNotEmpty);
}
