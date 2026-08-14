import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../subscription/presentation/widgets/plan_limit_dialog.dart';
import '../application/task_providers.dart';
import '../domain/task_item.dart';
import 'widgets/task_card.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  void _addTask(BuildContext context, WidgetRef ref) {
    final enforcement = ref.read(planEnforcementProvider);
    if (!enforcement.canCreateTask) {
      showPlanLimitDialog(
        context,
        message:
            'The ${enforcement.plan.name} plan allows up to '
            '${enforcement.plan.limits.maxActiveTasks} active tasks. '
            'Upgrade to Growth for unlimited tasks.',
        requiredPlanName: 'Growth',
      );
      return;
    }
    context.push('/tasks/new');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasksFab',
        onPressed: () => _addTask(context, ref),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              icon: Icons.checklist_outlined,
              title: 'No tasks yet',
              message: 'Add a task to start planning your day.',
              actionLabel: 'Add task',
              onAction: () => _addTask(context, ref),
            );
          }

          final today = DateTime.now();
          final todayTasks = <TaskItem>[];
          final upcomingTasks = <TaskItem>[];
          final completedTasks = <TaskItem>[];

          for (final task in tasks) {
            if (task.isDone) {
              completedTasks.add(task);
            } else if (task.dueDate != null && _isSameDay(task.dueDate!, today)) {
              todayTasks.add(task);
            } else {
              upcomingTasks.add(task);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              if (todayTasks.isNotEmpty) ..._section(context, ref, 'Today', todayTasks),
              if (upcomingTasks.isNotEmpty) ..._section(context, ref, 'Upcoming', upcomingTasks),
              if (completedTasks.isNotEmpty) ..._section(context, ref, 'Completed', completedTasks),
            ],
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<TaskItem> tasks,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.md),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.subtleText,
            letterSpacing: 0.5,
          ),
        ),
      ),
      ...tasks.map(
        (task) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TaskCard(
            task: task,
            onToggleDone: () => ref.read(taskActionsProvider).setDone(task.id, !task.isDone),
            onTap: () => context.push('/tasks/${task.id}/edit'),
          ),
        ),
      ),
    ];
  }
}
