import 'package:cloud_firestore/cloud_firestore.dart';

import 'google_sync_status.dart';

/// Mirrors `users/{uid}/integrations/google_calendar`.
class GoogleCalendarStatus {
  const GoogleCalendarStatus({
    required this.enabled,
    required this.status,
    this.lastSyncedAt,
    this.errorMessage,
  });

  final bool enabled;
  final GoogleSyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  static const notConnected = GoogleCalendarStatus(
    enabled: false,
    status: GoogleSyncStatus.notConnected,
  );

  factory GoogleCalendarStatus.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return notConnected;
    return GoogleCalendarStatus(
      enabled: data['enabled'] as bool? ?? false,
      status: GoogleSyncStatusX.fromName(data['status'] as String?),
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'] as String?,
    );
  }
}
