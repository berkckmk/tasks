import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../habits/application/habit_providers.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../application/today_actions.dart';
import '../application/today_providers.dart';
import 'widgets/quick_capture_bar.dart';
import 'widgets/time_rail.dart';

/// **Today** — `2b` Rail.
///
/// The route is still `/dashboard` and the class is still `DashboardScreen`;
/// only the title becomes "Today". Changing the path would break every deep
/// link and the post-sign-in redirect for no gain.
///
/// The screen is one vertical time rail carrying reminders, tasks and habits
/// together, because that is how a day is actually experienced — not as three
/// lists that each know a third of it. What used to be here (a progress card,
/// three coloured stat tiles, a "this week's focus" card and a placeholder
/// chart that said "coming soon") is gone: two of those were decoration and
/// one was a promise.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final now = DateTime.now();

    final habitsAsync = ref.watch(habitsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final remindersAsync = ref.watch(remindersProvider);

    // Loading only while *nothing* has arrived yet. Once any stream has a
    // value the rail renders what it has and fills in — a spinner over a
    // half-loaded day is worse than a short day.
    final isLoading =
        (habitsAsync.isLoading && !habitsAsync.hasValue) ||
        (tasksAsync.isLoading && !tasksAsync.hasValue) ||
        (remindersAsync.isLoading && !remindersAsync.hasValue);

    final firstError = [habitsAsync, tasksAsync, remindersAsync]
        .map((a) => a.hasError && !a.hasValue ? a.error : null)
        .firstWhere((e) => e != null, orElse: () => null);

    final entries = ref.watch(todayEntriesProvider);
    final nextUp = ref.watch(nextUpProvider);
    final actions = ref.read(todayActionsProvider);

    final done = entries.where((e) => e.done).length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (firstError != null)
              ErrorState(error: firstError)
            else
              ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  // Room for the quick-capture bar, which floats over the
                  // list rather than displacing it.
                  QuickCaptureBar.reservedHeight,
                ),
                children: [
                  _Header(now: now, done: done, total: entries.length),
                  const SizedBox(height: AppSpacing.xl),
                  if (entries.isEmpty)
                    EmptyState(
                      icon: AppIcons.sunHorizon,
                      title: 'Nothing scheduled today',
                      message:
                          'Capture a reminder below, or add a task with a due date '
                          'and it will appear here.',
                    )
                  else
                    _Rail(
                      entries: entries,
                      nextUp: nextUp,
                      now: now,
                      actions: actions,
                    ),
                ],
              ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: QuickCaptureBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.done, required this.total});

  final DateTime now;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(DateFormat('EEE d MMMM').format(now), color: c.inactive),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Today', style: AppType.h2.copyWith(color: c.text)),
            const Spacer(),
            if (total > 0)
              Text(
                '$done of $total done',
                style: AppType.meta.copyWith(color: c.inkAccent),
              ),
          ],
        ),
      ],
    );
  }
}

/// The rail itself: the hairline behind, the rows in front.
///
/// The now-line is inserted immediately above the next incomplete timed entry,
/// which is where the current moment actually falls — everything above it has
/// passed. Untimed entries are grouped under "Anytime" at the end rather than
/// pinned to midnight, so a task with only a due *date* doesn't claim the top
/// of the day.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.entries,
    required this.nextUp,
    required this.now,
    required this.actions,
  });

  final List<TodayEntry> entries;
  final TodayEntry? nextUp;
  final DateTime now;
  final TodayActions actions;

  @override
  Widget build(BuildContext context) {
    final timed = entries.where((e) => e.hasTime).toList();
    final untimed = entries.where((e) => !e.hasTime).toList();

    final rows = <Widget>[];

    for (final entry in timed) {
      final isNext = nextUp != null && identical(entry, nextUp);
      if (isNext) rows.add(RailNowLine(now: now));
      rows.add(_row(context, entry, isNext: isNext));
    }

    if (untimed.isNotEmpty) {
      rows.add(const RailGroupHeading('Anytime'));
      for (final entry in untimed) {
        rows.add(_row(context, entry, isNext: false));
      }
    }

    return Stack(
      children: [
        const RailLine(),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    TodayEntry entry, {
    required bool isNext,
  }) {
    void open() => _openEntry(context, entry);

    if (isNext) {
      return RailNextUpCard(
        key: ValueKey('next-${entry.kind.name}-${entry.id}'),
        entry: entry,
        onDone: () => actions.setDone(entry, true),
        onSnooze: actions.canSnooze(entry)
            ? () => actions.snooze(entry)
            : null,
        onTap: open,
      );
    }

    return RailEntry(
      key: ValueKey('${entry.kind.name}-${entry.id}'),
      entry: entry,
      onToggle: (value) => actions.setDone(entry, value),
      onTap: open,
    );
  }
}

/// Opens an entry in whichever editor owns it.
///
/// Habits live behind More now, so their edit route is pushed on the root
/// navigator like the other two — the rail doesn't have to care.
void _openEntry(BuildContext context, TodayEntry entry) {
  switch (entry.kind) {
    case TodayKind.reminder:
      context.push('/reminders/${entry.id}/edit');
    case TodayKind.task:
      context.push('/tasks/${entry.id}/edit');
    case TodayKind.habit:
      context.push('/habits/${entry.id}/edit');
  }
}
