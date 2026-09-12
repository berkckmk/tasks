/// Narrow, per-integration OAuth scopes — requested one at a time (only when
/// the user enables that specific integration), never all at once. Each is
/// the least-privileged scope Google offers for the job:
///  - `drive.file` (not full `drive`) only grants access to files this app
///    itself creates, not the user's whole Drive.
///  - `calendar.events` (not full `calendar`) only grants event
///    create/read/update/delete, not calendar management.
class GoogleScopes {
  GoogleScopes._();

  static const calendarEvents = 'https://www.googleapis.com/auth/calendar.events';
  static const sheets = 'https://www.googleapis.com/auth/spreadsheets';
  static const driveFile = 'https://www.googleapis.com/auth/drive.file';
  static const documents = 'https://www.googleapis.com/auth/documents';
}
