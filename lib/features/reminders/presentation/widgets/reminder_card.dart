import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_type.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/nocturne.dart';
import '../../../dashboard/application/today_actions.dart';
import '../../../dashboard/application/today_providers.dart';
import '../../domain/reminder.dart';
import '../reminders_screen.dart' show reminderTimeLabel;

/// One reminder row.
///
/// Flush text on a hairline, not a card — the group it sits in already carries
/// the edge, and a card inside a bordered group is two boxes deep for one
/// list. The name is unchanged because ~4 call sites use it.
///
/// The row is the redesign in miniature: a check circle on the left, the
/// title at 15px, **the `message` inline underneath at 12.5/1.5**, and a
/// right-aligned tabular time. That message field already existed and was
/// rendered as a truncated grey afterthought; surfacing it is the point.
class ReminderCard extends ConsumerWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    this.onTap,
    this.overdue = false,
    this.showDivider = true,
  });

  final ReminderItem reminder;
  final VoidCallback? onTap;

  /// Adds the `warning-circle` mark. Set by the Overdue group.
  final bool overdue;

  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final isDone = reminder.status == ReminderStatus.completed;
    final now = DateTime.now();

    final entry = TodayEntry(
      id: reminder.id,
      kind: TodayKind.reminder,
      title: reminder.title,
      note: reminder.message,
      time: reminder.dueAt,
      done: isDone,
    );

    return CompletedRow(
      completed: isDone,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: c.divider))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: c.accentTint(0.10),
            highlightColor: c.accentTint(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckCircle(
                    checked: isDone,
                    size: 17,
                    semanticLabel: reminder.title,
                    onChanged: (value) =>
                        ref.read(todayActionsProvider).setDone(entry, value),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (overdue && !isDone) ...[
                                Icon(
                                  AppIcons.warningCircle,
                                  size: 14,
                                  color: c.accent,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Text(
                                  reminder.title,
                                  style: AppType.title.copyWith(
                                    color: c.text,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: c.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (reminder.message.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            NoteText(reminder.message),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md + 1),
                    child: TimeGutter(
                      reminderTimeLabel(reminder.dueAt, now),
                      width: 42,
                      color: overdue && !isDone ? c.inkAccent : c.caption,
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
