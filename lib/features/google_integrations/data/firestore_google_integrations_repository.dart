import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/google_calendar_status.dart';
import '../domain/google_docs_status.dart';
import '../domain/google_drive_status.dart';
import '../domain/google_sheets_status.dart';

/// Read-only on purpose: every field in `integrations/*` is written by a
/// Cloud Function (Admin SDK) after a real OAuth exchange or API call —
/// never directly by the client. See `firestore.rules` and
/// `functions/src/google/*`.
class FirestoreGoogleIntegrationsRepository {
  FirestoreGoogleIntegrationsRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _firestore.collection('users').doc(_uid).collection('integrations').doc(id);

  Stream<GoogleCalendarStatus> watchCalendar() {
    return _doc('google_calendar').snapshots().map((s) => GoogleCalendarStatus.fromFirestore(s.data()));
  }

  Stream<GoogleSheetsStatus> watchSheets() {
    return _doc('google_sheets').snapshots().map((s) => GoogleSheetsStatus.fromFirestore(s.data()));
  }

  Stream<GoogleDriveStatus> watchDrive() {
    return _doc('google_drive').snapshots().map((s) => GoogleDriveStatus.fromFirestore(s.data()));
  }

  Stream<GoogleDocsStatus> watchDocs() {
    return _doc('google_docs').snapshots().map((s) => GoogleDocsStatus.fromFirestore(s.data()));
  }
}
