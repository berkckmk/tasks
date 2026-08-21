import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/firebase/firebase_providers.dart';

import '../data/firestore_reminder_repository.dart';
import '../domain/reminder.dart';

final reminderRepositoryProvider = Provider<ReminderRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreReminderRepository(ref.watch(firestoreProvider), uid);
});

final remindersProvider = StreamProvider<List<ReminderItem>>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchReminders();
});

class ReminderActions {
  ReminderActions(this._ref);
  final Ref _ref;

  Future<void> saveReminder({
    required String? id,
    required String title,
    required String message,
    required DateTime? dueAt,
    required ReminderStatus status,
  }) async {
    final repository = _ref.read(reminderRepositoryProvider);
    if (repository == null) return;
    await repository.saveReminder(
      id: id,
      title: title,
      message: message,
      dueAt: dueAt,
      status: status,
    );
  }

  Future<void> deleteReminder(String id) async {
    final repository = _ref.read(reminderRepositoryProvider);
    if (repository == null) return;
    await repository.deleteReminder(id);
  }
}

final reminderActionsProvider = Provider<ReminderActions>(
  (ref) => ReminderActions(ref),
);
