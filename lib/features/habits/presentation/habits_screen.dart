import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../subscription/presentation/guarded_create.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';
import 'widgets/habit_card.dart';
import '../../../core/widgets/app_glass_app_bar.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../core/layout/scroll_insets.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final filter = ref.watch(habitFilterProvider);

    return Scaffold(
      appBar: AppGlassAppBar(title: const Text('Habits')),
      floatingActionButton: AppFab(
        onPressed: () => GuardedCreate.habit(context, ref),
      ),
      body: habitsAsync.when(
        data: (habits) {
          final filtered = filter == null
              ? habits
              : habits.where((h) => h.category == filter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: filter == null,
                        onTap: () =>
                            ref.read(habitFilterProvider.notifier).state = null,
                      ),
                      ...HabitCategory.values.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: _FilterChip(
                            label: c.label,
                            selected: filter == c,
                            onTap: () =>
                                ref.read(habitFilterProvider.notifier).state =
                                    c,
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
                        message:
                            'Add your first habit to start building momentum.',
                        actionLabel: 'Add habit',
                        onAction: () => GuardedCreate.habit(context, ref),
                      )
                    : ListView.separated(
                        padding: scrollInsets(context),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final habit = filtered[index];
                          return HabitCard(
                            habit: habit,
                            onToggle: () => ref
                                .read(habitActionsProvider)
                                .toggleCompletionToday(
                                  habit.id,
                                  habit.isCompletedToday,
                                ),
                            onTap: () =>
                                context.push('/habits/${habit.id}/edit'),
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
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
  }
}
