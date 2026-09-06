import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/firebase/firebase_providers.dart';

import '../data/firestore_reminder_repository.dart';
import '../domain/reminder.dart';

import 'local_reminder_scheduler.dart';

final reminderRepositoryProvider = Provider<ReminderRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreReminderRepository(ref.watch(firestoreProvider), uid);
});

final remindersProvider = StreamProvider<List<ReminderItem>>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchReminders().map((list) {
    final scheduler = ref.read(localReminderSchedulerProvider);
    for (final reminder in list) {
      if (reminder.status == ReminderStatus.scheduled &&
          reminder.dueAt != null &&
          reminder.dueAt!.isAfter(DateTime.now())) {
        scheduler.schedule(reminder);
      }
    }
    return list;
  });
});

class ReminderActions {
  ReminderActions(this._ref);
  final Ref _ref;

  Future<String?> saveReminder({
    required String? id,
    required String title,
    required String message,
    required DateTime? dueAt,
    required ReminderStatus status,
    ReminderPriority? priority,
    bool starred = false,
    int? earlyAlertMinutes,
    String? repeatRule,
    String? location,
    String category = 'Hatırlatıcılarım',
    List<String> checklist = const [],
  }) async {
    final repository = _ref.read(reminderRepositoryProvider);
    if (repository == null) return null;
    final savedId = await repository.saveReminder(
      id: id,
      title: title,
      message: message,
      dueAt: dueAt,
      status: status,
      priority: priority,
      starred: starred,
      earlyAlertMinutes: earlyAlertMinutes,
      repeatRule: repeatRule,
      location: location,
      category: category,
      checklist: checklist,
    );

    final scheduler = _ref.read(localReminderSchedulerProvider);
    if (status == ReminderStatus.scheduled && dueAt != null) {
      await scheduler.schedule(
        ReminderItem(
          id: savedId,
          title: title,
          message: message,
          dueAt: dueAt,
          status: status,
          priority: priority ?? ReminderPriority.normal,
          starred: starred,
          earlyAlertMinutes: earlyAlertMinutes,
          repeatRule: repeatRule,
          location: location,
          category: category,
          checklist: checklist,
        ),
      );
    } else {
      await scheduler.cancel(savedId);
    }
    return savedId;
  }

  Future<void> deleteReminder(String id) async {
    final repository = _ref.read(reminderRepositoryProvider);
    if (repository == null) return;
    await repository.deleteReminder(id);
    await _ref.read(localReminderSchedulerProvider).cancel(id);
  }
}

final reminderActionsProvider = Provider<ReminderActions>(
  (ref) => ReminderActions(ref),
);

