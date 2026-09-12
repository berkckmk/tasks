import 'package:cloud_firestore/cloud_firestore.dart';

import 'google_sync_status.dart';

/// Mirrors `users/{uid}/integrations/google_sheets`.
class GoogleSheetsStatus {
  const GoogleSheetsStatus({
    required this.enabled,
    required this.status,
    this.spreadsheetId,
    this.spreadsheetUrl,
    this.lastExportedAt,
    this.selectedModules = const [],
    this.errorMessage,
  });

  final bool enabled;
  final GoogleSyncStatus status;
  final String? spreadsheetId;
  final String? spreadsheetUrl;
  final DateTime? lastExportedAt;
  final List<String> selectedModules;
  final String? errorMessage;

  static const notConnected = GoogleSheetsStatus(
    enabled: false,
    status: GoogleSyncStatus.notConnected,
  );

  factory GoogleSheetsStatus.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return notConnected;
    return GoogleSheetsStatus(
      enabled: data['enabled'] as bool? ?? false,
      status: GoogleSyncStatusX.fromName(data['status'] as String?),
      spreadsheetId: data['spreadsheetId'] as String?,
      spreadsheetUrl: data['spreadsheetUrl'] as String?,
      lastExportedAt: (data['lastExportedAt'] as Timestamp?)?.toDate(),
      selectedModules: (data['selectedModules'] as List<dynamic>?)?.cast<String>() ?? const [],
      errorMessage: data['errorMessage'] as String?,
    );
  }
}
