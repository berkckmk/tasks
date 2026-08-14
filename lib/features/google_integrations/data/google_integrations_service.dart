import 'package:cloud_functions/cloud_functions.dart';

import '../domain/google_integration_id.dart';

/// Thin wrapper around the Cloud Functions that actually talk to Google's
/// Calendar/Sheets/Drive/Docs APIs (see functions/src/google/*.ts). Nothing
/// in this class touches a Google API directly, and nothing in the app
/// calls `FirebaseFunctions` directly except through here.
class GoogleIntegrationsService {
  GoogleIntegrationsService(this._functions);

  final FirebaseFunctions _functions;

  /// Exchanges a one-time [serverAuthCode] (see
  /// AuthRepository.requestServerAuthCode) for tokens, server-side, and
  /// marks the integration connected.
  Future<void> connect(GoogleIntegrationId id, {required String serverAuthCode}) async {
    await _functions.httpsCallable('connectGoogleIntegration').call<void>({
      'integration': id.name,
      'authCode': serverAuthCode,
    });
  }

  /// Revokes the stored token server-side and marks the integration
  /// disconnected.
  Future<void> disconnect(GoogleIntegrationId id) async {
    await _functions.httpsCallable('disconnectGoogleIntegration').call<void>({
      'integration': id.name,
    });
  }

  Future<void> syncCalendarNow() async {
    await _functions.httpsCallable('syncGoogleCalendar').call<void>();
  }

  Future<String> exportToSheets(List<String> selectedModules) async {
    final result = await _functions.httpsCallable('exportToGoogleSheets').call<Map<String, dynamic>>({
      'modules': selectedModules,
    });
    return result.data['spreadsheetUrl'] as String;
  }

  Future<String> backupToDrive() async {
    final result = await _functions.httpsCallable('backupToGoogleDrive').call<Map<String, dynamic>>();
    return result.data['folderUrl'] as String;
  }

  Future<String> generateReport({
    required String type,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final result = await _functions.httpsCallable('generateGoogleDocsReport').call<Map<String, dynamic>>({
      'type': type,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
    });
    return result.data['reportId'] as String;
  }
}
