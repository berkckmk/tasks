import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
  });

  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;

  double get progress => targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  factory SavingsGoal.fromFirestore(String id, Map<String, dynamic> data) {
    return SavingsGoal(
      id: id,
      title: data['title'] as String? ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0,
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
    };
  }
}
