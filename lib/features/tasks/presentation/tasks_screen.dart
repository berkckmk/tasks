import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/layout/scroll_insets.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../subscription/presentation/guarded_create.dart';
import '../application/task_providers.dart';
import '../domain/task_item.dart';
import 'widgets/task_card.dart';

/// **Tasks** — the three groups (Today / Upcoming / Completed) with multi-selection support.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _startSelection(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<TaskItem> all) {
    setState(() {
      if (_selectedIds.length == all.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(all.map((t) => t.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Seçilen $count görev silinsin mi?',
      message: 'Bu işlem geri alınamaz.',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final toDelete = _selectedIds.toList();
    try {
      await Future.wait(
        toDelete.map(
          (id) => ref.read(taskActionsProvider).deleteTask(id),
        ),
      );
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('$count görev silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Görevler silinemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: _isSelectionMode
          ? null
          : AppFab(
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
                if (_isSelectionMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: c.edgeMd),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(AppIcons.x),
                          tooltip: 'Vazgeç',
                          onPressed: () => setState(() {
                            _selectedIds.clear();
                            _isSelectionMode = false;
                          }),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${_selectedIds.length} seçildi',
                          style: AppType.h5.copyWith(color: c.text),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _selectAll(tasks),
                          child: Text(
                            _selectedIds.length == tasks.length
                                ? 'Seçimi Kaldır'
                                : 'Tümünü Seç',
                            style: AppType.metaSmall.copyWith(color: c.accent),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(AppIcons.trash, color: Colors.redAccent),
                          tooltip: 'Seçilenleri Sil',
                          onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Text('Tasks', style: AppType.h2.copyWith(color: c.text)),
                      const Spacer(),
                      if (tasks.isNotEmpty)
                        GhostIconButton(
                          icon: AppIcons.checkSquareOffset,
                          tooltip: 'Toplu seçim',
                          onPressed: () =>
                              setState(() => _isSelectionMode = true),
                        ),
                    ],
                  ),
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
                    _Group(
                      label: 'Today',
                      tasks: todayTasks,
                      ref: ref,
                      isSelectionMode: _isSelectionMode,
                      selectedIds: _selectedIds,
                      onToggleSelect: _toggleSelect,
                      onStartSelection: _startSelection,
                    ),
                  if (upcomingTasks.isNotEmpty)
                    _Group(
                      label: 'Upcoming',
                      tasks: upcomingTasks,
                      ref: ref,
                      isSelectionMode: _isSelectionMode,
                      selectedIds: _selectedIds,
                      onToggleSelect: _toggleSelect,
                      onStartSelection: _startSelection,
                    ),
                  if (completedTasks.isNotEmpty)
                    _Group(
                      label: 'Completed',
                      tasks: completedTasks,
                      ref: ref,
                      isSelectionMode: _isSelectionMode,
                      selectedIds: _selectedIds,
                      onToggleSelect: _toggleSelect,
                      onStartSelection: _startSelection,
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
  const _Group({
    required this.label,
    required this.tasks,
    required this.ref,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.onStartSelection,
  });

  final String label;
  final List<TaskItem> tasks;
  final WidgetRef ref;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<String>? onStartSelection;

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
                      isSelectionMode: isSelectionMode,
                      isSelected: selectedIds.contains(tasks[i].id),
                      showDivider: i < tasks.length - 1,
                      onToggleDone: () => ref
                          .read(taskActionsProvider)
                          .setDone(tasks[i].id, !tasks[i].isDone),
                      onSelect: () => onToggleSelect?.call(tasks[i].id),
                      onLongPress: () {
                        if (!isSelectionMode) {
                          onStartSelection?.call(tasks[i].id);
                        }
                      },
                      onTap: () {
                        if (isSelectionMode) {
                          onToggleSelect?.call(tasks[i].id);
                        } else {
                          context.push('/tasks/${tasks[i].id}/edit');
                        }
                      },
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
