import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderStatus { scheduled, completed, snoozed, missed }

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.message,
    this.dueAt,
    required this.status,
  });

  final String id;
  final String title;
  final String message;
  final DateTime? dueAt;
  final ReminderStatus status;

  bool get isPast => dueAt != null && dueAt!.isBefore(DateTime.now());

  factory ReminderItem.fromFirestore(String id, Map<String, dynamic> data) {
    return ReminderItem(
      id: id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
      status: ReminderStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'scheduled'),
        orElse: () => ReminderStatus.scheduled,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
