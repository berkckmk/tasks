import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/layout/scroll_insets.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../subscription/presentation/guarded_create.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';
import '../domain/habit_schedule.dart';
import 'widgets/habit_card.dart';

/// **Habits** — reached from More now, not from a bottom tab.
///
/// Split into "Today" and "Other days" using the schedule derivation the
/// redesign adds ([HabitSchedule.isScheduledOn]). The old screen listed every
/// habit in one flat list regardless of when it was due, which is why a
/// Weekdays habit looked unfinished all weekend.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final habitsAsync = ref.watch(habitsProvider);
    final filter = ref.watch(habitFilterProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AppTopBar(),
      floatingActionButton: AppFab(
        tooltip: 'Add habit',
        onPressed: () => GuardedCreate.habit(context, ref),
      ),
      body: habitsAsync.when(
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (habits) {
          final filtered = filter == null
              ? habits
              : habits.where((h) => h.category == filter).toList();

          final today = filtered.where((h) => h.isScheduledOn(now)).toList()
            ..sort(_byDoneThenName);
          final otherDays = filtered
              .where((h) => !h.isScheduledOn(now))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return ListView(
            padding: scrollInsets(context),
            children: [
              Text('Habits', style: AppType.h2.copyWith(color: c.text)),
              const SizedBox(height: AppSpacing.lg),
              _CategoryFilter(filter: filter),
              const SizedBox(height: AppSpacing.xl),
              if (filtered.isEmpty)
                EmptyState(
                  icon: AppIcons.plant,
                  title: filter == null
                      ? 'No habits yet'
                      : 'No ${filter.label.toLowerCase()} habits',
                  message: filter == null
                      ? 'Add your first habit to start building momentum.'
                      : 'Nothing in this category yet.',
                  actionLabel: 'Add habit',
                  onAction: () => GuardedCreate.habit(context, ref),
                )
              else ...[
                if (today.isNotEmpty)
                  _Group(
                    label: 'Today',
                    habits: today,
                    done: today.where((h) => h.isCompletedToday).length,
                    ref: ref,
                  ),
                if (otherDays.isNotEmpty)
                  _Group(
                    label: 'Other days',
                    habits: otherDays,
                    ref: ref,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static int _byDoneThenName(Habit a, Habit b) {
    if (a.isCompletedToday != b.isCompletedToday) {
      return a.isCompletedToday ? 1 : -1;
    }
    return a.name.compareTo(b.name);
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.habits,
    required this.ref,
    this.done,
  });

  final String label;
  final List<Habit> habits;
  final WidgetRef ref;

  /// Shown as "3 of 5 done" beside the kicker. Null for a group where
  /// completion isn't the point — nothing on "Other days" is due today.
  final int? done;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Kicker(label, color: c.muted),
              const Spacer(),
              if (done != null)
                Text(
                  '$done of ${habits.length} done',
                  style: AppType.meta.copyWith(color: c.inkAccent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                children: [
                  for (var i = 0; i < habits.length; i++)
                    HabitCard(
                      key: ValueKey(habits[i].id),
                      habit: habits[i],
                      showDivider: i < habits.length - 1,
                      onToggle: () => ref
                          .read(habitActionsProvider)
                          .toggleCompletionToday(
                            habits[i].id,
                            habits[i].isCompletedToday,
                          ),
                      onTap: () => context.push('/habits/${habits[i].id}/edit'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// All / Morning / Evening / Health / Work.
///
/// A scrolling row of tag chips rather than a segmented control: there are
/// five options plus All, which is more than a segmented control reads well at
/// on a phone.
class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter({required this.filter});

  final HabitCategory? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(HabitCategory? value) =>
        ref.read(habitFilterProvider.notifier).state = value;

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            selected: filter == null,
            onTap: () => select(null),
          ),
          for (final category in HabitCategory.values)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _FilterChip(
                label: category.label,
                selected: filter == category,
                onTap: () => select(category),
              ),
            ),
        ],
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
    final c = AppColorsScheme.of(context);
    final radius = BorderRadius.circular(AppSpacing.radiusSm);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? c.accentTint() : Colors.transparent,
        borderRadius: radius,
        border: Border.all(color: selected ? c.accentTint(0.40) : c.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: c.accentTint(0.14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Text(
                label,
                style: AppType.meta.copyWith(
                  fontSize: 12.5,
                  color: selected ? c.inkAccent : c.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
