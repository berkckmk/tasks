import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_google_integrations_repository.dart';
import '../data/google_integrations_service.dart';
import '../domain/google_calendar_status.dart';
import '../domain/google_docs_status.dart';
import '../domain/google_drive_status.dart';
import '../domain/google_sheets_status.dart';

final googleIntegrationsRepositoryProvider = Provider<FirestoreGoogleIntegrationsRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreGoogleIntegrationsRepository(ref.watch(firestoreProvider), uid);
});

final googleIntegrationsServiceProvider = Provider<GoogleIntegrationsService>((ref) {
  return GoogleIntegrationsService(ref.watch(firebaseFunctionsProvider));
});

final googleCalendarStatusProvider = StreamProvider<GoogleCalendarStatus>((ref) {
  final repository = ref.watch(googleIntegrationsRepositoryProvider);
  if (repository == null) return Stream.value(GoogleCalendarStatus.notConnected);
  return repository.watchCalendar();
});

final googleSheetsStatusProvider = StreamProvider<GoogleSheetsStatus>((ref) {
  final repository = ref.watch(googleIntegrationsRepositoryProvider);
  if (repository == null) return Stream.value(GoogleSheetsStatus.notConnected);
  return repository.watchSheets();
});

final googleDriveStatusProvider = StreamProvider<GoogleDriveStatus>((ref) {
  final repository = ref.watch(googleIntegrationsRepositoryProvider);
  if (repository == null) return Stream.value(GoogleDriveStatus.notConnected);
  return repository.watchDrive();
});

final googleDocsStatusProvider = StreamProvider<GoogleDocsStatus>((ref) {
  final repository = ref.watch(googleIntegrationsRepositoryProvider);
  if (repository == null) return Stream.value(GoogleDocsStatus.notConnected);
  return repository.watchDocs();
});
