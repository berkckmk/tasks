import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Debug-only helper to seed a development Firestore project with
/// example Tasks / Reminders / Habits for the currently signed-in user.
///
/// Usage (recommended safe flow):
/// 1) Build and run the app in DEBUG mode on the device/emulator you want to
///    inspect.
/// 2) Sign in in the app with the account you want to seed (the UID below).
/// 3) From a debug-only UI button or a temporary debug route call:
///      await seedOneWeekPlanForCurrentUser();
///
/// NOTE: This writes to whichever Firebase project the app is configured for
/// (google-services.json / GoogleService-Info.plist). Double-check you are
/// pointing at the intended development project before running.

Future<void> seedOneWeekPlanForCurrentUser({
  FirebaseFirestore? firestore,
}) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    throw StateError('No signed-in user. Sign in before running the seed.');
  }
  final uid = user.uid;
  await _seedForUid(
    uid,
    firestore: firestore,
    displayName: user.displayName,
    email: user.email,
  );
}

/// Seed by finding a user document with the given email. If no user doc
/// exists with that email the function will throw — this avoids accidentally
/// creating a stray user doc in the project. Use this in dev where the user
/// already exists in `users/{uid}`.
Future<void> seedOneWeekPlanForEmail(
  String email, {
  FirebaseFirestore? firestore,
}) async {
  firestore ??= FirebaseFirestore.instance;
  final q = await firestore
      .collection('users')
      .where('email', isEqualTo: email)
      .limit(1)
      .get();
  if (q.docs.isEmpty) {
    throw StateError('No user document found for email: $email');
  }
  final doc = q.docs.first;
  final uid = doc.id;
  await _seedForUid(
    uid,
    firestore: firestore,
    displayName: doc.data()['displayName'] as String?,
    email: email,
  );
}

Future<void> _seedForUid(
  String uid, {
  FirebaseFirestore? firestore,
  String? displayName,
  String? email,
}) async {
  firestore ??= FirebaseFirestore.instance;

  final today = DateTime.now();
  final baseDay = DateTime(today.year, today.month, today.day);

  final habitSeeds = [
    ('Morning run', 'morning', true),
    ('Drink water', 'health', true),
    ('Read 20 pages', 'evening', false),
    ('Stretch', 'morning', true),
  ];

  final userDoc = firestore.collection('users').doc(uid);

  // Optional: ensure user profile doc exists (harmless merge)
  await userDoc.set({
    'uid': uid,
    if (displayName != null) 'displayName': displayName,
    if (email != null) 'email': email,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  }, SetOptions(merge: true));

  // Habits + habit_logs
  for (final tuple in habitSeeds) {
    final name = tuple.$1;
    final category = tuple.$2;
    final completedToday = tuple.$3;

    final habitRef = await userDoc.collection('habits').add({
      'name': name,
      'category': category,
      'frequencyLabel': 'Daily',
      'colorValue': 0xFF2E5E4E,
      'reminderTimeLabel': '08:00',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    for (var offset = -2; offset <= 3; offset++) {
      final date = DateTime(baseDay.year, baseDay.month, baseDay.day + offset);
      final dateKey = _dateKey(date);
      final isCompleted =
          offset <= 0 &&
          (completedToday || offset < 0 || dateKey == _dateKey(baseDay));
      await userDoc.collection('habit_logs').doc('${habitRef.id}_$dateKey').set(
        {
          'habitId': habitRef.id,
          'date': dateKey,
          'completed': isCompleted,
          'completedAt': isCompleted
              ? Timestamp.fromDate(date.add(const Duration(hours: 7)))
              : null,
        },
      );
    }
  }

  // Tasks
  final taskSeeds = [
    ('Plan the week', 'todo', 0),
    ('Finish invoice review', 'inProgress', 1),
    ('Book dentist visit', 'todo', 2),
    ('Reply to design notes', 'done', 3),
    ('Prepare workshop outline', 'todo', 4),
    ('Review budget', 'todo', 5),
    ('Deep clean desk', 'todo', 6),
  ];

  for (final t in taskSeeds) {
    final title = t.$1;
    final status = t.$2;
    final offset = t.$3;
    await userDoc.collection('tasks').add({
      'title': title,
      'description': 'Sample task for the upcoming week.',
      'dueDate': Timestamp.fromDate(baseDay.add(Duration(days: offset))),
      'priority': offset == 1 ? 'high' : 'medium',
      'status': status,
      'relatedGoalId': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  // Reminders
  final reminderSeeds = [
    ('Morning planning', 'Start the week strong', 0, 'scheduled'),
    ('Water refill reminder', 'Take a hydration break', 1, 'scheduled'),
    ('Workout check-in', 'Do the mobility session', 2, 'completed'),
    ('Call the client', 'Quick follow-up on open questions', 3, 'scheduled'),
    ('Meal prep', 'Prepare lunches for the next two days', 4, 'scheduled'),
    ('Review goals', 'Check progress and adjust priorities', 5, 'scheduled'),
    ('Reset the desk', 'Tidy and close open loops', 6, 'scheduled'),
  ];

  for (final r in reminderSeeds) {
    final title = r.$1;
    final message = r.$2;
    final offset = r.$3;
    final status = r.$4;
    await userDoc.collection('reminders').add({
      'title': title,
      'message': message,
      'dueAt': Timestamp.fromDate(
        baseDay.add(Duration(days: offset, hours: 9)),
      ),
      'status': status,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }
}

String _dateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
