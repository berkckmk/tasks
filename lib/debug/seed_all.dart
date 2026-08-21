import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Debug-only seeder that brings every data-bearing module of the app up to
/// [kSeedCount] records for the currently signed-in user.
///
/// Unlike [seedOneWeekPlanForCurrentUser] in `seed_dev.dart` (habits / tasks /
/// reminders only), this walks every collection the product actually stores,
/// and it goes through the *real* write paths — the `createHabit` /
/// `createTask` callables where firestore.rules denies client `create`, and
/// direct client writes everywhere else. A run therefore doubles as an
/// end-to-end check of the security rules and the Cloud Functions.
///
/// Two properties make it safe to run more than once:
///  * each module counts what is already there and writes only the shortfall,
///    so re-running after fixing one module doesn't duplicate the others;
///  * each module is attempted independently, so one failure is recorded and
///    the run continues instead of hiding the state of the rest.
///
/// Run it with the dedicated entrypoint:
///   `flutter run -t lib/debug/seed_main.dart -d <device>`
class SeedResult {
  const SeedResult(this.module, this.written, {this.error, this.existing = 0});

  final String module;
  final int written;
  final int existing;
  final String? error;

  bool get ok => error == null;
  bool get skipped => ok && written == 0;

  @override
  String toString() {
    if (!ok) return '$module: BAŞARISIZ ($error)';
    if (skipped) return '$module: atlandı (zaten $existing kayıt)';
    return '$module: $written yazıldı (önceki: $existing)';
  }
}

const int kSeedCount = 5;

Future<List<SeedResult>> seedAllModulesForCurrentUser({
  FirebaseFirestore? firestore,
  FirebaseFunctions? functions,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Oturum açık değil. Önce uygulamada giriş yapın.');
  }

  final db = firestore ?? FirebaseFirestore.instance;
  final fns = functions ?? FirebaseFunctions.instance;
  final userDoc = db.collection('users').doc(user.uid);

  final today = DateTime.now();
  final baseDay = DateTime(today.year, today.month, today.day);

  final results = <SeedResult>[];
  final habitIds = <String>[];
  final workoutIds = <String>[];

  // Habits — create is Admin-SDK-only, so this must go through the callable.
  results.add(
    await _seed(
      'habits',
      userDoc.collection('habits'),
      const [
        ('Morning run', 'morning', '07:00'),
        ('Drink 2L water', 'health', '10:00'),
        ('Read 20 pages', 'evening', '21:00'),
        ('Stretch routine', 'morning', '08:00'),
        ('Inbox zero', 'work', '17:00'),
      ],
      (seed) async {
        final (name, category, time) = seed;
        final res = await fns
            .httpsCallable('createHabit')
            .call<Map<String, dynamic>>({
              'name': name,
              'category': category,
              'frequencyLabel': 'Daily',
              'colorValue': 0xFF2E5E4E,
              'reminderTimeLabel': time,
            });
        habitIds.add(res.data['id'] as String);
      },
    ),
  );

  // Habit logs — one completed log per habit created in this run.
  results.add(
    await _run('habit_logs', () async {
      if (habitIds.isEmpty) {
        return const SeedResult('habit_logs', 0, existing: 0);
      }
      final dateKey = _dateKey(baseDay);
      for (final habitId in habitIds) {
        await userDoc.collection('habit_logs').doc('${habitId}_$dateKey').set({
          'habitId': habitId,
          'date': dateKey,
          'completed': true,
          'completedAt': Timestamp.fromDate(
            baseDay.add(const Duration(hours: 8)),
          ),
        });
      }
      return SeedResult('habit_logs', habitIds.length);
    }),
  );

  // Tasks — also callable-only. The function pins status to 'todo'.
  var taskOffset = 0;
  results.add(
    await _seed(
      'tasks',
      userDoc.collection('tasks'),
      const [
        ('Plan the week', 'high'),
        ('Finish invoice review', 'medium'),
        ('Book dentist visit', 'low'),
        ('Prepare workshop outline', 'medium'),
        ('Review Q3 budget', 'high'),
      ],
      (seed) async {
        final (title, priority) = seed;
        await fns.httpsCallable('createTask').call<Map<String, dynamic>>({
          'title': title,
          'description': 'Seed verisi — gerçek DB testi.',
          'priority': priority,
          'dueDate': baseDay
              .add(Duration(days: taskOffset++))
              .toIso8601String(),
        });
      },
    ),
  );

  // Reminders.
  var reminderOffset = 0;
  results.add(
    await _seed(
      'reminders',
      userDoc.collection('reminders'),
      const [
        ('Morning planning', 'Start the day with a 10-minute plan'),
        ('Hydration break', 'Refill the water bottle'),
        ('Workout check-in', 'Do the mobility session'),
        ('Call the client', 'Quick follow-up on open questions'),
        ('Review goals', 'Check progress and adjust priorities'),
      ],
      (seed) async {
        final (title, message) = seed;
        await userDoc.collection('reminders').add({
          'title': title,
          'message': message,
          'dueAt': Timestamp.fromDate(
            baseDay.add(Duration(days: reminderOffset++, hours: 9)),
          ),
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Goals — requires Growth or above (the closed beta grants it).
  var goalOffset = 0;
  results.add(
    await _seed(
      'goals',
      userDoc.collection('goals'),
      const [
        ('Ship v1.0', 'career', 'percentage', 0.6),
        ('Save 50k emergency fund', 'finance', 'percentage', 0.35),
        ('Run a half marathon', 'health', 'milestones', 0.0),
        ('Learn Kotlin properly', 'learning', 'percentage', 0.2),
        ('Read 24 books this year', 'personal', 'percentage', 0.5),
      ],
      (seed) async {
        final (title, category, progressType, progress) = seed;
        await userDoc.collection('goals').add({
          'title': title,
          'description': 'Seed verisi — gerçek DB testi.',
          'category': category,
          'targetDate': Timestamp.fromDate(
            baseDay.add(Duration(days: 30 + goalOffset++ * 15)),
          ),
          'progressType': progressType,
          'manualProgress': progress,
          'milestones': progressType == 'milestones'
              ? [
                  {'id': 'm1', 'title': '5K without stopping', 'isDone': true},
                  {'id': 'm2', 'title': '10K under an hour', 'isDone': false},
                  {'id': 'm3', 'title': 'Race day', 'isDone': false},
                ]
              : <Map<String, dynamic>>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Finance transactions — Complete plan only.
  var txOffset = 0;
  results.add(
    await _seed(
      'finance_transactions',
      userDoc.collection('finance_transactions'),
      const [
        ('income', 42000.0, 'Salary', 'Monthly salary'),
        ('expense', 1850.5, 'Groceries', 'Weekly shop'),
        ('expense', 620.0, 'Transport', 'Public transport card'),
        ('income', 7500.0, 'Freelance', 'Logo design project'),
        ('expense', 299.9, 'Subscriptions', 'Cloud storage annual'),
      ],
      (seed) async {
        final (type, amount, category, note) = seed;
        await userDoc.collection('finance_transactions').add({
          'type': type,
          'amount': amount,
          'category': category,
          'note': note,
          'date': Timestamp.fromDate(
            baseDay.subtract(Duration(days: txOffset++ * 3)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Savings goals.
  var savingsOffset = 0;
  results.add(
    await _seed(
      'savings_goals',
      userDoc.collection('savings_goals'),
      const [
        ('Emergency fund', 50000.0, 17500.0),
        ('New laptop', 65000.0, 42000.0),
        ('Summer trip', 30000.0, 8200.0),
        ('Home office chair', 12000.0, 12000.0),
        ('Camera lens', 22000.0, 3400.0),
      ],
      (seed) async {
        final (title, target, current) = seed;
        await userDoc.collection('savings_goals').add({
          'title': title,
          'targetAmount': target,
          'currentAmount': current,
          'targetDate': Timestamp.fromDate(
            baseDay.add(Duration(days: 60 + savingsOffset++ * 30)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Workouts.
  var workoutOffset = 0;
  results.add(
    await _seed(
      'workouts',
      userDoc.collection('workouts'),
      const ['Push day', 'Pull day', 'Leg day', 'Mobility', 'Easy 5K'],
      (name) async {
        final ref = await userDoc.collection('workouts').add({
          'name': name,
          'date': Timestamp.fromDate(
            baseDay.subtract(Duration(days: workoutOffset++)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });
        workoutIds.add(ref.id);
      },
    ),
  );

  // Exercise logs — attached to the workouts created in this run.
  results.add(
    await _run('exercise_logs', () async {
      if (workoutIds.isEmpty) {
        return const SeedResult('exercise_logs', 0, existing: 0);
      }
      const seeds = [
        ('Bench press', 4, 8, 60.0, true),
        ('Barbell row', 4, 10, 50.0, false),
        ('Back squat', 5, 5, 80.0, true),
        ('Hip mobility flow', 3, 12, 0.0, false),
        ('Treadmill run', 1, 1, 0.0, false),
      ];
      var count = 0;
      for (var i = 0; i < seeds.length && i < workoutIds.length; i++) {
        final (name, sets, reps, weight, pr) = seeds[i];
        await userDoc.collection('exercise_logs').add({
          'workoutId': workoutIds[i],
          'name': name,
          'sets': sets,
          'reps': reps,
          'weight': weight,
          'isPersonalRecord': pr,
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
      return SeedResult('exercise_logs', count);
    }),
  );

  // Learning items.
  results.add(
    await _seed(
      'learning_items',
      userDoc.collection('learning_items'),
      const [
        ('Designing Data-Intensive Applications', 'book', 'inProgress', 5),
        ('Flutter Performance Deep Dive', 'course', 'planned', 0),
        ('Syntax FM', 'podcast', 'inProgress', 4),
        ('The Pragmatic Programmer', 'book', 'completed', 5),
        ('Kotlin Coroutines in Practice', 'course', 'completed', 4),
      ],
      (seed) async {
        final (title, type, status, rating) = seed;
        await userDoc.collection('learning_items').add({
          'title': title,
          'type': type,
          'status': status,
          'rating': rating,
          'notes': 'Seed verisi — gerçek DB testi.',
          'keyTakeaways': ['Takeaway 1', 'Takeaway 2'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Content items.
  var contentOffset = 0;
  results.add(
    await _seed(
      'content_items',
      userDoc.collection('content_items'),
      const [
        ('Liquid glass widget teardown', 'YouTube', 'idea'),
        ('Firestore rules that actually hold', 'Blog', 'drafted'),
        ('Weekly habit review template', 'Instagram', 'scheduled'),
        ('Why we route creates through functions', 'Blog', 'published'),
        ('Flutter wireless debugging tips', 'X', 'scheduled'),
      ],
      (seed) async {
        final (title, platform, status) = seed;
        await userDoc.collection('content_items').add({
          'title': title,
          'platform': platform,
          'publishDate': Timestamp.fromDate(
            baseDay.add(Duration(days: contentOffset++ * 2)),
          ),
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  return results;
}

/// Tops [collection] up to [kSeedCount] by writing only the shortfall, taking
/// the tail of [seeds] so a re-run adds items the previous run didn't.
Future<SeedResult> _seed<T>(
  String module,
  CollectionReference<Map<String, dynamic>> collection,
  List<T> seeds,
  Future<void> Function(T seed) write,
) async {
  return _run(module, () async {
    final snapshot = await collection.count().get();
    final existing = snapshot.count ?? 0;
    final need = kSeedCount - existing;
    if (need <= 0) return SeedResult(module, 0, existing: existing);

    final pending = seeds.sublist(seeds.length - need);
    for (final seed in pending) {
      await write(seed);
    }
    return SeedResult(module, pending.length, existing: existing);
  });
}

Future<SeedResult> _run(
  String module,
  Future<SeedResult> Function() body,
) async {
  try {
    return await body();
  } catch (e) {
    return SeedResult(module, 0, error: e.toString());
  }
}

String _dateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
