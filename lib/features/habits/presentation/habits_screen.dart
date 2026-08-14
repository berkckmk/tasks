import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../subscription/presentation/widgets/plan_limit_dialog.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';
import 'widgets/habit_card.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  void _addHabit(BuildContext context, WidgetRef ref) {
    final enforcement = ref.read(planEnforcementProvider);
    if (!enforcement.canCreateHabit) {
      showPlanLimitDialog(
        context,
        message:
            'The ${enforcement.plan.name} plan allows up to '
            '${enforcement.plan.limits.maxActiveHabits} active habits. '
            'Upgrade to Growth for unlimited habits.',
        requiredPlanName: 'Growth',
      );
      return;
    }
    context.push('/habits/new');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final filter = ref.watch(habitFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habitsFab',
        onPressed: () => _addHabit(context, ref),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: habitsAsync.when(
        data: (habits) {
          final filtered =
              filter == null ? habits : habits.where((h) => h.category == filter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: filter == null,
                        onTap: () => ref.read(habitFilterProvider.notifier).state = null,
                      ),
                      ...HabitCategory.values.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: _FilterChip(
                            label: c.label,
                            selected: filter == c,
                            onTap: () => ref.read(habitFilterProvider.notifier).state = c,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.spa_outlined,
                        title: 'No habits yet',
                        message: 'Add your first habit to start building momentum.',
                        actionLabel: 'Add habit',
                        onAction: () => _addHabit(context, ref),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.xxl,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final habit = filtered[index];
                          return HabitCard(
                            habit: habit,
                            onToggle: () => ref
                                .read(habitActionsProvider)
                                .toggleCompletionToday(habit.id, habit.isCompletedToday),
                            onTap: () => context.push('/habits/${habit.id}/edit'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.deepGreen.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.deepGreen : AppColors.subtleText,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
    );
  }
}
