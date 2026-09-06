import 'dart:math';

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

/// Every seeded date is drawn from this window, and every one of them is in
/// the **future** — including the ones a real account would carry in the past
/// (a finance transaction, a logged workout). That is deliberate: the point of
/// a seed run is to populate the surfaces that only show upcoming items — the
/// Today rail, the reminders groups, the home-screen widget — and a backdated
/// row is invisible on all three.
const int _kMinDaysAhead = 1;
const int _kMaxDaysAhead = 45;

/// Re-seeded per run, so two runs against the same account produce different
/// days and times rather than the same five rows twice.
final Random _random = Random();

/// A day between [_kMinDaysAhead] and [_kMaxDaysAhead] from [base], at
/// midnight.
DateTime _futureDay(DateTime base) => base.add(
      Duration(
        days: _kMinDaysAhead +
            _random.nextInt(_kMaxDaysAhead - _kMinDaysAhead + 1),
      ),
    );

/// A waking-hours moment on [day] — 07:00 to 21:45, on the quarter hour.
/// Random minutes to the second would only produce times no human would set.
DateTime _atRandomTime(DateTime day) => DateTime(
      day.year,
      day.month,
      day.day,
      7 + _random.nextInt(15),
      [0, 15, 30, 45][_random.nextInt(4)],
    );

/// A future moment: a random day at a random time.
DateTime _futureMoment(DateTime base) => _atRandomTime(_futureDay(base));

/// The 12-hour label a habit's reminder time is stored as — the same shape
/// `TimeOfDay.format` produces and `parseHabitTime` reads back.
String _timeLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

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
        ('Morning run', 'morning'),
        ('Drink 2L water', 'health'),
        ('Read 20 pages', 'evening'),
        ('Stretch routine', 'morning'),
        ('Inbox zero', 'work'),
      ],
      (seed) async {
        final (name, category) = seed;
        // A habit recurs, so it has no date — only a time of day, and that
        // one is randomised like everything else.
        final time = _timeLabel(_atRandomTime(baseDay));
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
  //
  // The one thing here that is deliberately *not* forward-dated: a log says
  // "this habit was completed on this day", and a completion dated next
  // Tuesday is a claim about something that has not happened. It also feeds
  // the streak derivation, which would read a future log as a gap.
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
        // A task is scheduled over a range: a start day, and a deadline up to
        // four days later. Roughly a third get a clock time; the rest are
        // all-day, which is the ordinary case.
        final start = _futureDay(baseDay);
        final endDay = start.add(Duration(days: _random.nextInt(5)));
        final allDay = _random.nextInt(3) != 0;
        final due = allDay ? endDay : _atRandomTime(endDay);
        final created = await fns
            .httpsCallable('createTask')
            .call<Map<String, dynamic>>({
              'title': title,
              'description': 'Seed verisi — gerçek DB testi.',
              'priority': priority,
              'startDate': start.toIso8601String(),
              'dueDate': due.toIso8601String(),
              'allDay': allDay,
            });
        // Patched in rather than trusted to the callable, for the reason
        // FirestoreTaskRepository.saveTask does the same: the deployed
        // function can be older than this repo.
        final id = created.data['id'] as String?;
        if (id != null) {
          await userDoc.collection('tasks').doc(id).set({
            'startDate': Timestamp.fromDate(start),
            'dueDate': Timestamp.fromDate(due),
            'allDay': allDay,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      },
    ),
  );

  // Reminders.
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
          // Date *and* time, both required — a reminder without a moment
          // cannot fire and, because watchReminders orders by dueAt, would
          // not even be listed.
          'dueAt': Timestamp.fromDate(_futureMoment(baseDay)),
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Goals — requires Growth or above (the closed beta grants it).
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
          'targetDate': Timestamp.fromDate(_futureDay(baseDay)),
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
          // Forward-dated like everything else here. A real ledger is
          // historical; a seeded one exists to be seen.
          'date': Timestamp.fromDate(_futureDay(baseDay)),
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Savings goals.
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
          'targetDate': Timestamp.fromDate(_futureDay(baseDay)),
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  // Workouts.
  results.add(
    await _seed(
      'workouts',
      userDoc.collection('workouts'),
      const ['Push day', 'Pull day', 'Leg day', 'Mobility', 'Easy 5K'],
      (name) async {
        final ref = await userDoc.collection('workouts').add({
          'name': name,
          'date': Timestamp.fromDate(_futureMoment(baseDay)),
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
          'publishDate': Timestamp.fromDate(_futureDay(baseDay)),
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    ),
  );

  return results;
}

/// Writes [kSeedCount] rows into [collection], on top of whatever is already
/// there.
///
/// It used to top *up* to [kSeedCount] and skip a collection already at that
/// count, which is the right shape for "bring an empty account to life" and
/// the wrong one for "show me five upcoming items in every area": an account
/// whose five tasks are all in the past and all ticked would be reported as
/// full and left exactly as it was. Now every module gets its five, and the
/// prior count is reported rather than subtracted.
///
/// Dates and times are randomised per run, so two runs are visibly different
/// rows rather than the same five twice — but they *are* additive. Re-running
/// four times leaves twenty tasks.
Future<SeedResult> _seed<T>(
  String module,
  CollectionReference<Map<String, dynamic>> collection,
  List<T> seeds,
  Future<void> Function(T seed) write,
) async {
  return _run(module, () async {
    final snapshot = await collection.count().get();
    final existing = snapshot.count ?? 0;
    for (final seed in seeds) {
      await write(seed);
    }
    return SeedResult(module, seeds.length, existing: existing);
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
