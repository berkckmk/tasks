import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/edit_target.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../../google_integrations/application/google_integrations_providers.dart';
import '../../google_integrations/domain/google_sync_status.dart';
import '../application/task_providers.dart';
import '../domain/task_item.dart';
import '../../../core/widgets/app_glass_app_bar.dart';
import '../../../core/widgets/app_dialogs.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  const AddEditTaskScreen({super.key, this.taskId});

  final String? taskId;

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  String? _relatedGoalId;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFromExisting(TaskItem? task) {
    if (_initialized || task == null) return;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _dueDate = task.dueDate;
    _priority = task.priority;
    _relatedGoalId = task.relatedGoalId;
    _initialized = true;
  }

  Future<void> _confirmDelete(BuildContext context, String taskId) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete task?',
      message: 'This can\'t be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(taskActionsProvider).deleteTask(taskId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Couldn't delete task: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskId != null;
    final title = isEditing ? 'Edit task' : 'New task';
    // The goal list only populates a dropdown, so an empty fallback is fine
    // here — unlike the task itself, resolved strictly below.
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Goal>[];

    final target = EditTarget.resolve<TaskItem>(
      id: widget.taskId,
      async: ref.watch(tasksProvider),
      idOf: (task) => task.id,
    );

    final TaskItem? existing;
    switch (target) {
      case EditTargetLoading():
        return EditTargetLoadingScreen(title: title);
      case EditTargetFailed(:final error):
        return EditTargetMissingScreen(title: title, message: '', error: error);
      case EditTargetMissing():
        return EditTargetMissingScreen(
          title: title,
          message: "This task no longer exists. It may have been deleted on another device.",
        );
      case EditTargetFound(:final item):
        existing = item;
        _initFromExisting(existing);
      case EditTargetCreating():
        existing = null;
    }

    final calendarConnected =
        ref.watch(googleCalendarStatusProvider).valueOrNull?.status ==
        GoogleSyncStatus.connected;

    return Scaffold(
      appBar: AppGlassAppBar(
        title: Text(title),
        actions: [
          if (existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete task',
              onPressed: () => _confirmDelete(context, existing!.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Task title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Due date', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _dueDate == null
                  ? 'Set a due date (optional)'
                  : DateFormat.yMMMd().format(_dueDate!),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Priority', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: TaskPriority.values
                .map(
                  (p) => ChoiceChip(
                    label: Text(p.label),
                    selected: _priority == p,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _priority = p),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Related goal', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: _relatedGoalId,
            decoration: const InputDecoration(labelText: 'None'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              ...goals.map(
                (g) => DropdownMenuItem<String?>(
                  value: g.id,
                  child: Text(g.title),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _relatedGoalId = value),
          ),
          if (isEditing &&
              existing != null &&
              calendarConnected &&
              _dueDate != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.deepGreen,
                value: existing.syncEnabled,
                title: const Text('Sync to Google Calendar'),
                subtitle: const Text(
                  "Creates an event on this task's due date.",
                ),
                onChanged: (value) => ref
                    .read(taskActionsProvider)
                    .setSyncEnabled(existing!.id, value),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save task',
            expand: true,
            onPressed: _isSaving
                ? null
                : () async {
                    final title = _titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a task title'),
                        ),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    try {
                      await ref
                          .read(taskActionsProvider)
                          .saveTask(
                            id: existing?.id,
                            title: title,
                            description: _descriptionController.text.trim(),
                            dueDate: _dueDate,
                            priority: _priority,
                            status: existing?.status ?? TaskStatus.todo,
                            relatedGoalId: _relatedGoalId,
                          );
                      if (context.mounted) context.pop();
                    } on FirebaseFunctionsException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message ?? "Couldn't save task."),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Couldn't save task: $e")),
                        );
                      }
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
