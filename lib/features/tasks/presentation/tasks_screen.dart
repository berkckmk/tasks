import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/layout/scroll_insets.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../subscription/presentation/guarded_create.dart';
import '../application/task_providers.dart';
import '../domain/task_item.dart';
import 'widgets/task_card.dart';

/// **Tasks** — the same three groups as before, retokenised into the rail's
/// row shape.
///
/// The grouping (Today / Upcoming / Completed) is unchanged: it was already
/// the right split, and the redesign is a visual and structural change, not a
/// re-think of what a task list is for. What changed is that a group is now
/// headed by a numeral and a kicker, rows are flush on hairlines, and the
/// `description` is visible.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: AppFab(
        tooltip: 'Add task',
        onPressed: () => GuardedCreate.task(context, ref),
      ),
      body: SafeArea(
        bottom: false,
        child: tasksAsync.when(
          error: (error, stackTrace) => ErrorState(error: error),
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (tasks) {
            final today = DateTime.now();
            final todayTasks = <TaskItem>[];
            final upcomingTasks = <TaskItem>[];
            final completedTasks = <TaskItem>[];

            for (final task in tasks) {
              if (task.isDone) {
                completedTasks.add(task);
              } else if (task.dueDate != null &&
                  _isSameDay(task.dueDate!, today)) {
                todayTasks.add(task);
              } else {
                upcomingTasks.add(task);
              }
            }

            for (final list in [todayTasks, upcomingTasks]) {
              list.sort(_byDueDate);
            }

            return ListView(
              padding: scrollInsets(context),
              children: [
                Text('Tasks', style: AppType.h2.copyWith(color: c.text)),
                const SizedBox(height: AppSpacing.xl),
                if (tasks.isEmpty)
                  EmptyState(
                    icon: AppIcons.checkSquareOffset,
                    title: 'No tasks yet',
                    message: 'Add a task to start planning your day.',
                    actionLabel: 'Add task',
                    onAction: () => GuardedCreate.task(context, ref),
                  )
                else ...[
                  if (todayTasks.isNotEmpty)
                    _Group(label: 'Today', tasks: todayTasks, ref: ref),
                  if (upcomingTasks.isNotEmpty)
                    _Group(label: 'Upcoming', tasks: upcomingTasks, ref: ref),
                  if (completedTasks.isNotEmpty)
                    _Group(
                      label: 'Completed',
                      tasks: completedTasks,
                      ref: ref,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Undated tasks after dated ones — an "Upcoming" group led by items with no
  /// date at all reads as a backlog rather than as what is coming.
  static int _byDueDate(TaskItem a, TaskItem b) {
    if (a.dueDate == null && b.dueDate == null) {
      return a.title.compareTo(b.title);
    }
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.tasks, required this.ref});

  final String label;
  final List<TaskItem> tasks;
  final WidgetRef ref;

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
              Text(
                '${tasks.length}',
                style: AppType.numeral.copyWith(color: c.text),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Kicker(label, color: c.muted),
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
                  for (var i = 0; i < tasks.length; i++)
                    TaskCard(
                      key: ValueKey(tasks[i].id),
                      task: tasks[i],
                      showDivider: i < tasks.length - 1,
                      onToggleDone: () => ref
                          .read(taskActionsProvider)
                          .setDone(tasks[i].id, !tasks[i].isDone),
                      onTap: () => context.push('/tasks/${tasks[i].id}/edit'),
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
