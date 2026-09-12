import 'package:cloud_firestore/cloud_firestore.dart';

enum LearningType { book, course, podcast }

extension LearningTypeLabel on LearningType {
  String get label => switch (this) {
        LearningType.book => 'Book',
        LearningType.course => 'Course',
        LearningType.podcast => 'Podcast',
      };
}

enum LearningStatus { planned, inProgress, completed }

extension LearningStatusLabel on LearningStatus {
  String get label => switch (this) {
        LearningStatus.planned => 'Planned',
        LearningStatus.inProgress => 'In progress',
        LearningStatus.completed => 'Completed',
      };
}

class LearningItem {
  const LearningItem({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    this.rating = 0,
    this.notes = '',
    this.keyTakeaways = const [],
  });

  final String id;
  final String title;
  final LearningType type;
  final LearningStatus status;

  /// 0-5.
  final int rating;
  final String notes;
  final List<String> keyTakeaways;

  factory LearningItem.fromFirestore(String id, Map<String, dynamic> data) {
    return LearningItem(
      id: id,
      title: data['title'] as String? ?? '',
      type: LearningType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => LearningType.book,
      ),
      status: LearningStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => LearningStatus.planned,
      ),
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String? ?? '',
      keyTakeaways: (data['keyTakeaways'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'type': type.name,
      'status': status.name,
      'rating': rating,
      'notes': notes,
      'keyTakeaways': keyTakeaways,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
