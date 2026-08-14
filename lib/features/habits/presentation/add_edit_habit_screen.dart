import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../google_integrations/application/google_integrations_providers.dart';
import '../../google_integrations/domain/google_sync_status.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  const AddEditHabitScreen({super.key, this.habitId});

  final String? habitId;

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  final _nameController = TextEditingController();
  HabitCategory _category = HabitCategory.morning;
  String _frequencyLabel = 'Daily';
  String? _reminderTimeLabel;
  Color _color = AppColors.deepGreen;
  bool _initialized = false;
  bool _isSaving = false;

  static const _frequencyOptions = ['Daily', '3x / week', '5x / week', 'Weekdays', 'Weekly'];
  static const _colorOptions = [
    AppColors.deepGreen,
    AppColors.mutedBlue,
    AppColors.amber,
    Color(0xFF8E6C88),
    Color(0xFF3E6E7E),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initFromExisting(Habit? habit) {
    if (_initialized || habit == null) return;
    _nameController.text = habit.name;
    _category = habit.category;
    _frequencyLabel = habit.frequencyLabel;
    _reminderTimeLabel = habit.reminderTimeLabel;
    _color = habit.color;
    _initialized = true;
  }

  Future<void> _confirmDelete(BuildContext context, String habitId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text('This also removes its completion history. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(habitActionsProvider).deleteHabit(habitId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't delete habit: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habitId != null;
    final habitsAsync = ref.watch(habitsProvider);
    final habits = habitsAsync.maybeWhen(data: (d) => d, orElse: () => const <Habit>[]);

    Habit? existing;
    if (isEditing) {
      for (final h in habits) {
        if (h.id == widget.habitId) {
          existing = h;
          break;
        }
      }
      _initFromExisting(existing);
    }

    final calendarConnected =
        ref.watch(googleCalendarStatusProvider).valueOrNull?.status == GoogleSyncStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit habit' : 'New habit'),
        actions: [
          if (isEditing && existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete habit',
              onPressed: () => _confirmDelete(context, existing!.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Habit name'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: HabitCategory.values
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
          Text('Frequency', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: _frequencyOptions
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _frequencyLabel == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _frequencyLabel = f),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Reminder time', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null && context.mounted) {
                setState(() => _reminderTimeLabel = picked.format(context));
              }
            },
            icon: const Icon(Icons.alarm_outlined),
            label: Text(_reminderTimeLabel ?? 'Set a reminder (optional)'),
          ),
          if (isEditing && existing != null && calendarConnected) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.deepGreen,
                value: existing.syncEnabled,
                title: const Text('Sync reminder to Google Calendar'),
                subtitle: const Text('Creates a recurring event for this habit\'s reminder.'),
                onChanged: (value) =>
                    ref.read(habitActionsProvider).setSyncEnabled(existing!.id, value),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: _colorOptions
                .map(
                  (c) => GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: _color.toARGB32() == c.toARGB32()
                            ? Border.all(color: AppColors.charcoal, width: 2)
                            : null,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save habit',
            expand: true,
            onPressed: _isSaving
                ? null
                : () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a habit name')),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    try {
                      await ref.read(habitActionsProvider).saveHabit(
                            id: existing?.id,
                            name: name,
                            category: _category,
                            frequencyLabel: _frequencyLabel,
                            colorValue: _color.toARGB32(),
                            reminderTimeLabel: _reminderTimeLabel,
                          );
                      if (context.mounted) context.pop();
                    } on FirebaseFunctionsException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message ?? "Couldn't save habit.")),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Couldn't save habit: $e")),
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
