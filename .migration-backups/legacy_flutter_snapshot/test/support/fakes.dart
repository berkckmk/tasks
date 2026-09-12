import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:steady_progress/core/firebase/callable_service.dart';
import 'package:steady_progress/core/firebase/firebase_providers.dart';

/// Records callable invocations and writes straight to the fake Firestore.
///
/// Habit and task creation goes through Cloud Functions (firestore.rules
/// denies client `create` on both), so without this the lists in a widget
/// test are permanently empty — and before `CallableService` existed, the
/// real `FirebaseFunctions.instance` threw `[core/no-app]`, which Riverpod
/// turned into an `AsyncError` and the screens rendered as `ErrorState`
/// while the assertions still passed.
class FakeCallableService implements CallableService {
  FakeCallableService(this._firestore, this._uid);

  final FakeFirebaseFirestore _firestore;
  final String _uid;

  /// Every call made, in order — assert against this to check a screen
  /// actually reached the backend.
  final List<({String name, Map<String, dynamic>? data})> calls = [];

  @override
  Future<Map<String, dynamic>?> call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    calls.add((name: name, data: data));

    final collection = switch (name) {
      'createHabit' => 'habits',
      'createTask' => 'tasks',
      _ => null,
    };
    if (collection == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection(collection)
        .add({
          ...?data,
          if (collection == 'tasks') 'status': 'todo',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
    return {'id': doc.id};
  }
}

/// A signed-in user with a seeded profile and subscription document.
class TestBackend {
  TestBackend._(this.auth, this.firestore, this.callables, this.uid);

  final MockFirebaseAuth auth;
  final FakeFirebaseFirestore firestore;
  final FakeCallableService callables;
  final String uid;

  static Future<TestBackend> signedIn({
    String uid = 'test-uid',
    String planId = 'starter',
    bool onboardingCompleted = true,
  }) async {
    final auth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: uid,
        email: 'jane@example.com',
        displayName: 'Jane Doe',
      ),
      signedIn: true,
    );
    final firestore = FakeFirebaseFirestore();

    final userDoc = firestore.collection('users').doc(uid);
    await userDoc.set({
      'uid': uid,
      'email': 'jane@example.com',
      'displayName': 'Jane Doe',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'selectedPlan': planId,
      'onboardingCompleted': onboardingCompleted,
      'timezone': 'UTC',
      'appPreferences': {'notificationsEnabled': true, 'theme': 'system'},
    });
    await userDoc.collection('subscription').doc('status').set({
      'planId': planId,
      'status': 'active',
      'startedAt': Timestamp.now(),
      'expiresAt': null,
      'billingProvider': 'none',
      'isTrialActive': false,
      'trialEndsAt': null,
    });

    return TestBackend._(
      auth,
      firestore,
      FakeCallableService(firestore, uid),
      uid,
    );
  }

  Future<void> addHabit(String name, {String category = 'morning'}) async {
    await firestore.collection('users').doc(uid).collection('habits').add({
      'name': name,
      'category': category,
      'frequencyLabel': 'Daily',
      'colorValue': 0xFF2E5E4E,
      'reminderTimeLabel': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> addTask(String title, {String status = 'todo'}) async {
    await firestore.collection('users').doc(uid).collection('tasks').add({
      'title': title,
      'description': '',
      'dueDate': null,
      'priority': 'medium',
      'status': status,
      'relatedGoalId': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> addGoal(String title) async {
    await firestore.collection('users').doc(uid).collection('goals').add({
      'title': title,
      'description': '',
      'category': 'personal',
      'targetDate': null,
      'manualProgress': 0.0,
      'milestones': <Map<String, dynamic>>[],
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> seedOneWeekPlan() async {
    final today = DateTime.now();
    final baseDay = DateTime(today.year, today.month, today.day);

    final habitSeeds = [
      ('Morning run', 'morning', true),
      ('Drink water', 'health', true),
      ('Read 20 pages', 'evening', false),
      ('Stretch', 'morning', true),
    ];

    for (final (name, category, completedToday) in habitSeeds) {
      final habitRef = await firestore
          .collection('users')
          .doc(uid)
          .collection('habits')
          .add({
            'name': name,
            'category': category,
            'frequencyLabel': 'Daily',
            'colorValue': 0xFF2E5E4E,
            'reminderTimeLabel': '08:00',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });

      for (var offset = -2; offset <= 3; offset++) {
        final date = DateTime(
          baseDay.year,
          baseDay.month,
          baseDay.day + offset,
        );
        final dateKey =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final isCompleted =
            offset <= 0 &&
            (completedToday || offset < 0 || dateKey == _dateKey(baseDay));
        await firestore
            .collection('users')
            .doc(uid)
            .collection('habit_logs')
            .doc('${habitRef.id}_$dateKey')
            .set({
              'habitId': habitRef.id,
              'date': dateKey,
              'completed': isCompleted,
              'completedAt': isCompleted
                  ? Timestamp.fromDate(date.add(const Duration(hours: 7)))
                  : null,
            });
      }
    }

    final taskSeeds = [
      ('Plan the week', 'todo', 0),
      ('Finish invoice review', 'inProgress', 1),
      ('Book dentist visit', 'todo', 2),
      ('Reply to design notes', 'done', 3),
      ('Prepare workshop outline', 'todo', 4),
      ('Review budget', 'todo', 5),
      ('Deep clean desk', 'todo', 6),
    ];

    for (final (title, status, offset) in taskSeeds) {
      await firestore.collection('users').doc(uid).collection('tasks').add({
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

    final reminderSeeds = [
      ('Morning planning', 'Start the week strong', 0, 'scheduled'),
      ('Water refill reminder', 'Take a hydration break', 1, 'scheduled'),
      ('Workout check-in', 'Do the mobility session', 2, 'completed'),
      ('Call the client', 'Quick follow-up on open questions', 3, 'scheduled'),
      ('Meal prep', 'Prepare lunches for the next two days', 4, 'scheduled'),
      ('Review goals', 'Check progress and adjust priorities', 5, 'scheduled'),
      ('Reset the desk', 'Tidy and close open loops', 6, 'scheduled'),
    ];

    for (final (title, message, offset, status) in reminderSeeds) {
      await firestore.collection('users').doc(uid).collection('reminders').add({
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

  static String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  List<Override> get overrides => [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
    // Without this the habit/task repositories construct
    // FirebaseFunctions.instance and throw [core/no-app].
    callableServiceProvider.overrideWithValue(callables),
  ];
}
