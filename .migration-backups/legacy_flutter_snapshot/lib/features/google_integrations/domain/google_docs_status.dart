import 'package:cloud_firestore/cloud_firestore.dart';

import 'google_sync_status.dart';

/// Mirrors `users/{uid}/integrations/google_docs`. Individual generated
/// reports live in `users/{uid}/reports/{reportId}` (see the reports
/// feature) — this doc just tracks connection state.
class GoogleDocsStatus {
  const GoogleDocsStatus({
    required this.enabled,
    required this.status,
    this.lastReportGeneratedAt,
    this.errorMessage,
  });

  final bool enabled;
  final GoogleSyncStatus status;
  final DateTime? lastReportGeneratedAt;
  final String? errorMessage;

  static const notConnected = GoogleDocsStatus(
    enabled: false,
    status: GoogleSyncStatus.notConnected,
  );

  factory GoogleDocsStatus.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return notConnected;
    return GoogleDocsStatus(
      enabled: data['enabled'] as bool? ?? false,
      status: GoogleSyncStatusX.fromName(data['status'] as String?),
      lastReportGeneratedAt: (data['lastReportGeneratedAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'] as String?,
    );
  }
}
