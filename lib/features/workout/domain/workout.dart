import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  const Workout({required this.id, required this.name, required this.date});

  final String id;
  final String name;
  final DateTime date;

  factory Workout.fromFirestore(String id, Map<String, dynamic> data) {
    return Workout(
      id: id,
      name: data['name'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'date': Timestamp.fromDate(date)};
  }
}
