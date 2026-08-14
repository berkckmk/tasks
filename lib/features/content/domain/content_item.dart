import 'package:cloud_firestore/cloud_firestore.dart';

enum ContentStatus { idea, drafted, scheduled, published }

extension ContentStatusLabel on ContentStatus {
  String get label => switch (this) {
        ContentStatus.idea => 'Idea',
        ContentStatus.drafted => 'Drafted',
        ContentStatus.scheduled => 'Scheduled',
        ContentStatus.published => 'Published',
      };
}

const contentPlatforms = ['Instagram', 'YouTube', 'TikTok', 'Blog', 'Newsletter', 'X', 'Other'];

class ContentItem {
  const ContentItem({
    required this.id,
    required this.title,
    required this.platform,
    this.publishDate,
    required this.status,
  });

  final String id;
  final String title;
  final String platform;
  final DateTime? publishDate;
  final ContentStatus status;

  /// Performance metrics (views, likes, etc.) aren't collected yet — this
  /// is a placeholder for when a publishing integration can pull them in.

  factory ContentItem.fromFirestore(String id, Map<String, dynamic> data) {
    return ContentItem(
      id: id,
      title: data['title'] as String? ?? '',
      platform: data['platform'] as String? ?? 'Other',
      publishDate: (data['publishDate'] as Timestamp?)?.toDate(),
      status: ContentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ContentStatus.idea,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'platform': platform,
      'publishDate': publishDate == null ? null : Timestamp.fromDate(publishDate!),
      'status': status.name,
      'updatedAt': Timestamp.now(),
    };
  }
}
