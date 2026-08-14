import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../application/goal_providers.dart';
import '../domain/goal.dart';
import '../domain/milestone.dart';

class AddEditGoalScreen extends ConsumerStatefulWidget {
  const AddEditGoalScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends ConsumerState<AddEditGoalScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _milestoneController = TextEditingController();
  GoalCategory _category = GoalCategory.personal;
  GoalProgressType _progressType = GoalProgressType.percentage;
  DateTime? _targetDate;
  double _manualProgress = 0;
  List<Milestone> _milestones = [];
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  void _initFromExisting(Goal? goal) {
    if (_initialized || goal == null) return;
    _titleController.text = goal.title;
    _descriptionController.text = goal.description;
    _category = goal.category;
    _progressType = goal.progressType;
    _targetDate = goal.targetDate;
    _manualProgress = goal.manualProgress;
    _milestones = List.of(goal.milestones);
    _initialized = true;
  }

  void _addMilestone() {
    final text = _milestoneController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _milestones = [
        ..._milestones,
        Milestone(id: 'm_${DateTime.now().millisecondsSinceEpoch}', title: text),
      ];
      _milestoneController.clear();
    });
  }

  Future<void> _confirmDelete(BuildContext context, String goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(goalActionsProvider).deleteGoal(goalId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't delete goal: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goalId != null;
    final goalsAsync = ref.watch(goalsProvider);
    final goals = goalsAsync.maybeWhen(data: (d) => d, orElse: () => const <Goal>[]);

    Goal? existing;
    if (isEditing) {
      for (final g in goals) {
        if (g.id == widget.goalId) {
          existing = g;
          break;
        }
      }
      _initFromExisting(existing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit goal' : 'New goal'),
        actions: [
          if (isEditing && existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete goal',
              onPressed: () => _confirmDelete(context, existing!.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Goal title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: GoalCategory.values
                .map(
                  (c) => ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Target date', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _targetDate == null ? 'Set a target date (optional)' : DateFormat.yMMMd().format(_targetDate!),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Progress type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: GoalProgressType.values
                .map(
                  (t) => ChoiceChip(
                    label: Text(t.label),
                    selected: _progressType == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _progressType = t),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_progressType == GoalProgressType.percentage) ...[
            Text('Progress: ${(_manualProgress * 100).round()}%', style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: _manualProgress,
              onChanged: (v) => setState(() => _manualProgress = v),
              activeColor: AppColors.deepGreen,
            ),
          ] else ...[
            Text('Milestones', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ..._milestones.map(
              (m) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: m.isDone,
                activeColor: AppColors.deepGreen,
                title: Text(m.title),
                onChanged: (checked) {
                  setState(() {
                    _milestones = _milestones
                        .map((e) => e.id == m.id ? e.copyWith(isDone: checked ?? false) : e)
                        .toList();
                  });
                },
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _milestones = _milestones.where((e) => e.id != m.id).toList();
                    });
                  },
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _milestoneController,
                    decoration: const InputDecoration(labelText: 'Add a milestone'),
                    onSubmitted: (_) => _addMilestone(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.deepGreen),
                  onPressed: _addMilestone,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save goal',
            expand: true,
            onPressed: _isSaving
                ? null
                : () async {
                    final title = _titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a goal title')),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    try {
                      await ref.read(goalActionsProvider).saveGoal(
                            id: existing?.id,
                            title: title,
                            description: _descriptionController.text.trim(),
                            category: _category,
                            targetDate: _targetDate,
                            progressType: _progressType,
                            manualProgress: _manualProgress,
                            milestones: _milestones,
                          );
                      if (context.mounted) context.pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Couldn't save goal: $e")),
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
