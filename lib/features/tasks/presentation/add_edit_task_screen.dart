import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/edit_target.dart';
import '../../../core/widgets/nocturne.dart';
import '../../../core/widgets/sheet_page.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../../google_integrations/application/google_integrations_providers.dart';
import '../../google_integrations/domain/google_sync_status.dart';
import '../application/task_providers.dart';
import '../domain/task_item.dart';

/// **New task** — `2b`: a sheet over the dimmed rail.
///
/// A 20px title field and a **chip row** — due · priority · goal · calendar —
/// in place of the six labelled `.field` blocks the old screen stacked. The
/// difference is not decoration: labelled fields make every option look
/// equally necessary, so a task with a title and nothing else felt unfinished.
/// Chips state what is *set*, and stay quiet otherwise.
///
/// The route is unchanged (`/tasks/new`, `/tasks/:taskId/edit`); only the
/// presentation is a sheet — see [sheetPage].
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
      message: "This can't be undone.",
    );
    if (!confirmed) return;

    try {
      await ref.read(taskActionsProvider).deleteTask(taskId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't delete task: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final isEditing = widget.taskId != null;
    final title = isEditing ? 'Edit task' : 'New task';
    // The goal list only populates a picker, so an empty fallback is fine
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
          message:
              'This task no longer exists. It may have been deleted on another device.',
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
    final canSync = calendarConnected && _dueDate != null && existing != null;
    final goalTitle = _relatedGoalId == null
        ? null
        : goals
              .where((g) => g.id == _relatedGoalId)
              .map((g) => g.title)
              .firstOrNull;

    return SheetPanel(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Kicker(title, color: c.muted),
                const Spacer(),
                if (existing != null)
                  GhostIconButton(
                    icon: AppIcons.trash,
                    tooltip: 'Delete task',
                    onPressed: () => _confirmDelete(context, existing!.id),
                  ),
                GhostIconButton(
                  icon: AppIcons.x,
                  tooltip: 'Close',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // 20px, borderless, autofocused. The title is the only field a
            // task actually needs, so it is the only one that looks like a
            // field.
            TextField(
              controller: _titleController,
              autofocus: !isEditing,
              style: AppType.h5.copyWith(fontSize: 20, color: c.text),
              cursorColor: c.accent,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'What needs doing?',
                hintStyle: AppType.h5.copyWith(
                  fontSize: 20,
                  color: c.inactive,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descriptionController,
              maxLines: null,
              minLines: 2,
              style: AppType.bodySmall.copyWith(color: c.note),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Notes',
                hintStyle: AppType.bodySmall.copyWith(color: c.inactive),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Chip(
                  icon: AppIcons.calendarBlank,
                  label: _dueDate == null
                      ? 'Due'
                      : DateFormat('d MMM').format(_dueDate!),
                  set: _dueDate != null,
                  onTap: _pickDue,
                  onClear: _dueDate == null
                      ? null
                      : () => setState(() => _dueDate = null),
                ),
                _Chip(
                  icon: AppIcons.flag,
                  label: _priority == TaskPriority.medium
                      ? 'Priority'
                      : _priority.label,
                  set: _priority != TaskPriority.medium,
                  onTap: _pickPriority,
                ),
                _Chip(
                  icon: AppIcons.target,
                  label: goalTitle ?? 'Goal',
                  set: goalTitle != null,
                  onTap: goals.isEmpty ? null : () => _pickGoal(goals),
                  onClear: _relatedGoalId == null
                      ? null
                      : () => setState(() => _relatedGoalId = null),
                ),
                // Only offered when it can actually do something: the sync is
                // performed by a Cloud Function against a saved task with a
                // due date, so on a brand-new task there is nothing to sync
                // yet. Shown-but-dead would be worse than absent.
                if (canSync)
                  _Chip(
                    icon: AppIcons.googleLogo,
                    label: existing.syncEnabled ? 'Calendar on' : 'Calendar',
                    set: existing.syncEnabled,
                    onTap: () => ref
                        .read(taskActionsProvider)
                        .setSyncEnabled(existing!.id, !existing.syncEnabled),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: _isSaving ? null : () => context.pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // flex 2 against the Cancel button's flex 1.
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: _isSaving ? 'Saving…' : 'Save task',
                    expand: true,
                    onPressed: _isSaving ? null : () => _save(existing),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Today / Tomorrow / pick — the three answers that cover almost every
  /// task, without opening a calendar for the two most common ones.
  Future<void> _pickDue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final choice = await _showOptions<DateTime?>(
      title: 'Due',
      options: [
        _Option('Today', today),
        _Option('Tomorrow', today.add(const Duration(days: 1))),
        _Option('Pick a date…', null),
      ],
    );
    if (choice == null || !mounted) return;

    if (choice.value != null) {
      setState(() => _dueDate = choice.value);
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _pickPriority() async {
    final choice = await _showOptions<TaskPriority>(
      title: 'Priority',
      options: [
        for (final p in TaskPriority.values) _Option(p.label, p),
      ],
    );
    if (choice != null && mounted) setState(() => _priority = choice.value);
  }

  Future<void> _pickGoal(List<Goal> goals) async {
    final choice = await _showOptions<String?>(
      title: 'Related goal',
      options: [
        const _Option('None', null),
        for (final g in goals) _Option(g.title, g.id),
      ],
    );
    if (choice != null && mounted) {
      setState(() => _relatedGoalId = choice.value);
    }
  }

  /// A short list of choices, as a sheet rather than a dropdown.
  ///
  /// `DropdownButtonFormField` renders a Material menu with its own surface,
  /// elevation and tint, none of which are Nocturne's — and it needs a
  /// labelled form field around it, which is exactly what the chip row
  /// replaced.
  Future<_Option<T>?> _showOptions<T>({
    required String title,
    required List<_Option<T>> options,
  }) {
    final c = AppColorsScheme.of(context);

    return showModalBottomSheet<_Option<T>>(
      context: context,
      backgroundColor: c.surface,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      elevation: 0,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
        side: BorderSide(color: c.edgeMd),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Kicker(title, color: c.muted),
            ),
            for (final option in options)
              ListTile(
                title: Text(
                  option.label,
                  style: AppType.body.copyWith(color: c.text),
                ),
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _save(TaskItem? existing) async {
    final title = _titleController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (title.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
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
      if (mounted) context.pop();
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? "Couldn't save task.")),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't save task: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _Option<T> {
  const _Option(this.label, this.value);
  final String label;
  final T value;
}

/// One chip in the composer's row.
///
/// Unset: hairline edge, muted label — it names the *kind* of thing it sets
/// ("Due"). Set: accent tint ground and `inkAccent` label showing the value
/// ("3 Sep"), with an `x` to clear it where clearing is meaningful.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.set,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool set;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final enabled = onTap != null;
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final tone = set ? c.inkAccent : c.muted;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: set ? c.accentTint() : Colors.transparent,
          borderRadius: radius,
          border: Border.all(color: set ? c.accentTint(0.40) : c.divider),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: c.accentTint(0.14),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm + 2,
                AppSpacing.sm,
                onClear == null ? AppSpacing.sm + 2 : AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: tone),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: AppType.meta.copyWith(
                      fontSize: 12.5,
                      color: tone,
                    ),
                  ),
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Icon(AppIcons.x, size: 11, color: tone),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
