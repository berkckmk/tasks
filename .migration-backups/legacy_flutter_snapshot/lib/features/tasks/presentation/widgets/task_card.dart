import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_type.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/nocturne.dart';
import '../../domain/task_item.dart';

/// One task row.
///
/// Flush text on a hairline rather than a card, matching the reminder rows —
/// three pillars, one row shape. The check circle is the shared toggle, so
/// ticking a task here, on the Today rail, or on the home-screen widget is
/// visibly the same action.
///
/// The `description` renders inline underneath the title. It was already on
/// the model and already saved by the editor; nothing but this row ever showed
/// it.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleDone,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.showDivider = true,
  });

  final TaskItem task;
  final VoidCallback onToggleDone;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return CompletedRow(
      completed: task.isDone,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? c.accentTint(0.08) : Colors.transparent,
          border: showDivider
              ? Border(bottom: BorderSide(color: c.divider))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSelectionMode ? onSelect : onTap,
            onLongPress: onLongPress,
            splashColor: c.accentTint(0.10),
            highlightColor: c.accentTint(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        right: AppSpacing.sm,
                      ),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected ? c.accent : c.inactive,
                      ),
                    )
                  else
                    CheckCircle(
                      checked: task.isDone,
                      size: 17,
                      semanticLabel: task.title,
                      onChanged: (_) => onToggleDone(),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: AppType.title.copyWith(
                              color: c.text,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: c.text,
                            ),
                          ),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            NoteText(task.description, maxLines: 2),
                          ],
                          // The priority chip is gone from the row. It was a
                          // coloured pill in one of three hues on every task,
                          // which in a mono-accent palette is three accents —
                          // and it repeated on rows where priority was the
                          // default and told the reader nothing. Only a
                          // *high* priority earns a mark now, and it is the
                          // accent as a line, not a fill.
                          if (task.priority == TaskPriority.high &&
                              !task.isDone) ...[
                            const SizedBox(height: 5),
                            _HighPriorityMark(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md + 1),
                    child: TimeGutter(
                      taskGutterLabel(task),
                      width: 42,
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

class _HighPriorityMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 1, color: c.accent),
        const SizedBox(width: 5),
        Text(
          'High',
          style: AppType.metaSmall.copyWith(color: c.inkAccent),
        ),
      ],
    );
  }
}

/// The 42px gutter's line for a task.
///
/// A single day prints the date; a range prints both ends stacked by an en
/// dash, which is as much as the gutter fits. A timed task prints the time
/// instead — that is the more specific fact, and the date is already carried
/// by the group the row sits in.
String taskGutterLabel(TaskItem task) {
  final due = task.dueDate;
  if (due == null) return '';
  if (!task.allDay) return DateFormat.jm().format(due);
  if (!task.spansDays) return DateFormat('d MMM').format(due);
  final start = task.effectiveStart!;
  return '${DateFormat('d/M').format(start)}–${DateFormat('d/M').format(due)}';
}
