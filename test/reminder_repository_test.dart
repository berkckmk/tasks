import 'package:flutter_test/flutter_test.dart';
import 'package:steady_progress/features/reminders/data/firestore_reminder_repository.dart';
import 'package:steady_progress/features/reminders/domain/reminder.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreReminderRepository (fake firestore)', () {
    late TestBackend backend;
    late FirestoreReminderRepository repo;

    setUpAll(() async {
      backend = await TestBackend.signedIn();
      await backend.seedOneWeekPlan();
      repo = FirestoreReminderRepository(backend.firestore, backend.uid);
    });

    test('seed produces 7 reminders', () async {
      final list = await repo.watchReminders().first;
      expect(list.length, 7);
    });

    test('create -> edit -> delete reminder flow', () async {
      final before = await repo.watchReminders().first;
      final beforeCount = before.length;

      // Create
      await repo.saveReminder(
        id: null,
        title: 'Test create reminder',
        message: 'Created from unit test',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        status: ReminderStatus.scheduled,
      );

      // allow the fake backend to settle and read newest list
      final afterCreate = await repo.watchReminders().first;
      expect(afterCreate.length, beforeCount + 1);

      // find the created doc id by title in the underlying fake firestore
      final createdDoc = await backend.firestore
          .collection('users')
          .doc(backend.uid)
          .collection('reminders')
          .where('title', isEqualTo: 'Test create reminder')
          .get();
      expect(createdDoc.docs, isNotEmpty);
      final createdId = createdDoc.docs.first.id;

      // Edit
      await repo.saveReminder(
        id: createdId,
        title: 'Edited reminder title',
        message: 'Edited by unit test',
        dueAt: DateTime.now().add(const Duration(days: 3)),
        status: ReminderStatus.completed,
      );

      final editedSnapshot = await backend.firestore
          .collection('users')
          .doc(backend.uid)
          .collection('reminders')
          .doc(createdId)
          .get();
      expect(editedSnapshot.exists, isTrue);
      final data = editedSnapshot.data()!;
      expect(data['title'], 'Edited reminder title');
      expect(data['status'], ReminderStatus.completed.name);

      // Delete
      await repo.deleteReminder(createdId);

      final afterDelete = await repo.watchReminders().first;
      expect(afterDelete.length, beforeCount);
    });

    test('saves priority and auto-upgrades medication to important', () async {
      // 1. Explicit important priority save
      await repo.saveReminder(
        id: null,
        title: 'Custom Important Meeting',
        message: '',
        dueAt: DateTime.now().add(const Duration(days: 1)),
        priority: ReminderPriority.important,
        status: ReminderStatus.scheduled,
      );

      final list = await repo.watchReminders().first;
      final custom = list.firstWhere((r) => r.title == 'Custom Important Meeting');
      expect(custom.priority, ReminderPriority.important);

      // 2. Medicine keyword in title auto-upgrades to important even if stored without priority
      await repo.saveReminder(
        id: null,
        title: 'Duxet ilacı',
        message: 'Akşam dozu',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
        status: ReminderStatus.scheduled,
      );

      final list2 = await repo.watchReminders().first;
      final med = list2.firstWhere((r) => r.title == 'Duxet ilacı');
      expect(med.isMedicine, isTrue);
      expect(med.priority, ReminderPriority.important);

      // Clean up
      await repo.deleteReminder(custom.id);
      await repo.deleteReminder(med.id);
    });

    test('saves and retrieves rich detail fields', () async {
      final id = await repo.saveReminder(
        id: null,
        title: 'Diş Hekimi Randevusu',
        message: 'Röntgen sonuçlarını unutma',
        dueAt: DateTime.now().add(const Duration(days: 3)),
        status: ReminderStatus.scheduled,
        priority: ReminderPriority.important,
        starred: true,
        earlyAlertMinutes: 30,
        repeatRule: 'Her hafta',
        location: 'Kadıköy Diş Polikliniği',
        category: 'Sağlık & İlaç',
        checklist: ['Kimlik kartı', 'Röntgen dosyası', 'Randevu fişi'],
      );

      final list = await repo.watchReminders().first;
      final dentist = list.firstWhere((r) => r.id == id);

      expect(dentist.starred, isTrue);
      expect(dentist.earlyAlertMinutes, 30);
      expect(dentist.repeatRule, 'Her hafta');
      expect(dentist.location, 'Kadıköy Diş Polikliniği');
      expect(dentist.category, 'Sağlık & İlaç');
      expect(dentist.checklist, ['Kimlik kartı', 'Röntgen dosyası', 'Randevu fişi']);

      await repo.deleteReminder(id);
    });
  });
}
