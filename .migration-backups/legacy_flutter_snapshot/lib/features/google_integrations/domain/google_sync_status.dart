enum GoogleSyncStatus { notConnected, connected, syncing, error }

extension GoogleSyncStatusX on GoogleSyncStatus {
  static GoogleSyncStatus fromName(String? name) => GoogleSyncStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => GoogleSyncStatus.notConnected,
      );

  String get label => switch (this) {
        GoogleSyncStatus.notConnected => 'Not connected',
        GoogleSyncStatus.connected => 'Connected',
        GoogleSyncStatus.syncing => 'Syncing...',
        GoogleSyncStatus.error => 'Sync error',
      };
}
