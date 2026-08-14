import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { weekly, monthly }

extension ReportTypeLabel on ReportType {
  String get label => switch (this) {
        ReportType.weekly => 'Weekly',
        ReportType.monthly => 'Monthly',
      };
}

enum ReportStatus { pending, generating, ready, failed }

extension ReportStatusLabel on ReportStatus {
  String get label => switch (this) {
        ReportStatus.pending => 'Pending',
        ReportStatus.generating => 'Generating...',
        ReportStatus.ready => 'Ready',
        ReportStatus.failed => 'Failed',
      };
}

/// Mirrors `users/{uid}/reports/{reportId}` — written by the
/// `generateGoogleDocsReport` Cloud Function (see
/// functions/src/google/docs.ts), read-only from the client.
class Report {
  const Report({
    required this.id,
    required this.type,
    required this.periodStart,
    required this.periodEnd,
    this.googleDocId,
    this.googleDocUrl,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final ReportType type;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? googleDocId;
  final String? googleDocUrl;
  final DateTime createdAt;
  final ReportStatus status;

  factory Report.fromFirestore(String id, Map<String, dynamic> data) {
    return Report(
      id: id,
      type: ReportType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ReportType.weekly,
      ),
      periodStart: (data['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      googleDocId: data['googleDocId'] as String?,
      googleDocUrl: data['googleDocUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ReportStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ReportStatus.pending,
      ),
    );
  }
}
