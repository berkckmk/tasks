import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/edit_target.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/constants/app_icons.dart';

class AddEditReminderScreen extends ConsumerStatefulWidget {
  const AddEditReminderScreen({super.key, this.reminderId});

  final String? reminderId;

  @override
  ConsumerState<AddEditReminderScreen> createState() =>
      _AddEditReminderScreenState();
}

class _AddEditReminderScreenState extends ConsumerState<AddEditReminderScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _dueAt;
  ReminderStatus _status = ReminderStatus.scheduled;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _initFromExisting(ReminderItem? reminder) {
    if (_initialized || reminder == null) return;
    _titleController.text = reminder.title;
    _messageController.text = reminder.message;
    _dueAt = reminder.dueAt;
    _status = reminder.status;
    _initialized = true;
  }

  Future<void> _confirmDelete(BuildContext context, String reminderId) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete reminder?',
      message: 'This can\'t be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(reminderActionsProvider).deleteReminder(reminderId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't delete reminder: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reminderId != null;
    final title = isEditing ? 'Edit reminder' : 'New reminder';

    final target = EditTarget.resolve<ReminderItem>(
      id: widget.reminderId,
      async: ref.watch(remindersProvider),
      idOf: (r) => r.id,
    );

    ReminderItem? existing;
    switch (target) {
      case EditTargetLoading():
        return EditTargetLoadingScreen(title: title);
      case EditTargetFailed(:final error):
        return EditTargetMissingScreen(title: title, message: '', error: error);
      case EditTargetMissing():
        return EditTargetMissingScreen(
          title: title,
          message: "This reminder no longer exists.",
        );
      case EditTargetFound(:final item):
        existing = item;
        _initFromExisting(existing);
      case EditTargetCreating():
        existing = null;
    }

    return Scaffold(
      appBar: AppTopBar(
        title: Text(title),
        actions: [
          if (existing != null)
            IconButton(
              icon: const Icon(AppIcons.trash),
              tooltip: 'Delete reminder',
              onPressed: () => _confirmDelete(context, existing!.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message (optional)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('When', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dueAt ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(
                    () => _dueAt = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                } else {
                  setState(
                    () => _dueAt = DateTime(date.year, date.month, date.day),
                  );
                }
              }
            },
            icon: const Icon(AppIcons.calendarBlank),
            label: Text(
              _dueAt == null
                  ? 'Set date & time (optional)'
                  : _dueAt!.toLocal().toString(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Status', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: ReminderStatus.values
                .map(
                  (s) => ChoiceChip(
                    label: Text(s.name),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save reminder',
            expand: true,
            onPressed: _isSaving
                ? null
                : () async {
                    final titleText = _titleController.text.trim();
                    if (titleText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a reminder title'),
                        ),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    try {
                      await ref
                          .read(reminderActionsProvider)
                          .saveReminder(
                            id: existing?.id,
                            title: titleText,
                            message: _messageController.text.trim(),
                            dueAt: _dueAt,
                            status: _status,
                          );
                      if (context.mounted) context.pop();
                    } on FirebaseFunctionsException catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.message ?? "Couldn't save reminder.",
                            ),
                          ),
                        );
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Couldn't save reminder: $e")),
                        );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
