import '../../../core/google/google_scopes.dart';

enum GoogleIntegrationId { calendar, sheets, drive, docs }

extension GoogleIntegrationIdX on GoogleIntegrationId {
  /// Doc id under `users/{uid}/integrations/{docId}`.
  String get docId => switch (this) {
        GoogleIntegrationId.calendar => 'google_calendar',
        GoogleIntegrationId.sheets => 'google_sheets',
        GoogleIntegrationId.drive => 'google_drive',
        GoogleIntegrationId.docs => 'google_docs',
      };

  /// The single narrow scope requested when the user enables *this*
  /// integration — never requested until then.
  String get scope => switch (this) {
        GoogleIntegrationId.calendar => GoogleScopes.calendarEvents,
        GoogleIntegrationId.sheets => GoogleScopes.sheets,
        GoogleIntegrationId.drive => GoogleScopes.driveFile,
        GoogleIntegrationId.docs => GoogleScopes.documents,
      };

  String get label => switch (this) {
        GoogleIntegrationId.calendar => 'Google Calendar Sync',
        GoogleIntegrationId.sheets => 'Google Sheets Export',
        GoogleIntegrationId.drive => 'Google Drive Backup',
        GoogleIntegrationId.docs => 'Google Docs Reports',
      };

  String get permissionExplanation => switch (this) {
        GoogleIntegrationId.calendar =>
          'Lets Steady Progress create, update, and delete events it creates on your '
              'Google Calendar (tasks, habit reminders, goal milestones). It cannot see or '
              'change your other calendar events.',
        GoogleIntegrationId.sheets =>
          'Lets Steady Progress create and update spreadsheets to export your data. It '
              'cannot access your other Google Sheets.',
        GoogleIntegrationId.drive =>
          "Lets Steady Progress create a dedicated app folder in your Drive and save "
              "backup files there. It cannot see or access the rest of your Drive.",
        GoogleIntegrationId.docs =>
          'Lets Steady Progress create Google Docs to generate your progress reports. It '
              'cannot access your other Google Docs.',
      };
}
