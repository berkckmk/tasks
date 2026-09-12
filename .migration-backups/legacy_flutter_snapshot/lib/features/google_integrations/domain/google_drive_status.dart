import 'package:cloud_firestore/cloud_firestore.dart';

import 'google_sync_status.dart';

/// Mirrors `users/{uid}/integrations/google_drive`.
class GoogleDriveStatus {
  const GoogleDriveStatus({
    required this.enabled,
    required this.status,
    this.folderId,
    this.folderUrl,
    this.lastBackupAt,
    this.errorMessage,
  });

  final bool enabled;
  final GoogleSyncStatus status;
  final String? folderId;
  final String? folderUrl;
  final DateTime? lastBackupAt;
  final String? errorMessage;

  static const notConnected = GoogleDriveStatus(
    enabled: false,
    status: GoogleSyncStatus.notConnected,
  );

  factory GoogleDriveStatus.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return notConnected;
    return GoogleDriveStatus(
      enabled: data['enabled'] as bool? ?? false,
      status: GoogleSyncStatusX.fromName(data['status'] as String?),
      folderId: data['folderId'] as String?,
      folderUrl: data['folderUrl'] as String?,
      lastBackupAt: (data['lastBackupAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'] as String?,
    );
  }
}
