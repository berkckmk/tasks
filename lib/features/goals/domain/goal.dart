import 'package:cloud_firestore/cloud_firestore.dart';

import 'milestone.dart';

enum GoalCategory { career, finance, health, learning, personal }

extension GoalCategoryLabel on GoalCategory {
  String get label => switch (this) {
        GoalCategory.career => 'Career',
        GoalCategory.finance => 'Finance',
        GoalCategory.health => 'Health',
        GoalCategory.learning => 'Learning',
        GoalCategory.personal => 'Personal',
      };
}

enum GoalProgressType { percentage, milestones }

extension GoalProgressTypeLabel on GoalProgressType {
  String get label => switch (this) {
        GoalProgressType.percentage => 'Percentage',
        GoalProgressType.milestones => 'Milestones',
      };
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.targetDate,
    required this.progressType,
    this.manualProgress = 0,
    this.milestones = const [],
  });

  final String id;
  final String title;
  final String description;
  final GoalCategory category;
  final DateTime? targetDate;
  final GoalProgressType progressType;

  /// Used when [progressType] is [GoalProgressType.percentage]. 0.0 - 1.0.
  final double manualProgress;
  final List<Milestone> milestones;

  /// 0.0 - 1.0, derived from milestones when that progress type is used.
  double get progress {
    if (progressType == GoalProgressType.percentage || milestones.isEmpty) {
      return manualProgress;
    }
    final done = milestones.where((m) => m.isDone).length;
    return done / milestones.length;
  }

  factory Goal.fromFirestore(String id, Map<String, dynamic> data) {
    return Goal(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: GoalCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => GoalCategory.personal,
      ),
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      progressType: GoalProgressType.values.firstWhere(
        (t) => t.name == data['progressType'],
        orElse: () => GoalProgressType.percentage,
      ),
      manualProgress: (data['manualProgress'] as num?)?.toDouble() ?? 0,
      milestones: (data['milestones'] as List<dynamic>? ?? [])
          .map((m) => Milestone.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category.name,
      'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
      'progressType': progressType.name,
      'manualProgress': manualProgress,
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    };
  }

  Goal copyWith({
    String? title,
    String? description,
    GoalCategory? category,
    DateTime? targetDate,
    bool clearTargetDate = false,
    GoalProgressType? progressType,
    double? manualProgress,
    List<Milestone>? milestones,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      progressType: progressType ?? this.progressType,
      manualProgress: manualProgress ?? this.manualProgress,
      milestones: milestones ?? this.milestones,
    );
  }
}
