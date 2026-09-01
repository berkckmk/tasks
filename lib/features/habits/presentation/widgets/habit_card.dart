import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_type.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/nocturne.dart';
import '../../domain/habit.dart';

/// One habit row.
///
/// The same shape as a reminder and a task row: the shared check circle, the
/// title, a muted meta line, and a right-aligned tabular time.
///
/// **`habit.color` no longer paints anything.** Each habit carried a
/// user-picked colour that drew a 40px ring and tinted a category badge, so a
/// list of five habits was five hues — five accents in a palette that has one.
/// The field is still on the model and still saved (this is a visual redesign;
/// nothing is removed from the data), it simply isn't the thing that
/// distinguishes one row from another any more. The name does that.
class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.onToggle,
    this.onTap,
    this.showDivider = true,
  });

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    // "Health · Daily · 12-day streak" — one line, one colour, in the order
    // the eye needs it.
    final meta = [
      habit.category.label,
      habit.frequencyLabel,
      if (habit.streak > 0) '${habit.streak}-day streak',
    ].join(' · ');

    return CompletedRow(
      completed: habit.isCompletedToday,
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
                children: [
                  CheckCircle(
                    checked: habit.isCompletedToday,
                    size: 17,
                    semanticLabel: habit.name,
                    onChanged: (_) => onToggle(),
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
                            habit.name,
                            style: AppType.title.copyWith(
                              color: c.text,
                              decoration: habit.isCompletedToday
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: c.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            style: AppType.metaSmall.copyWith(
                              fontSize: 11.5,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md + 1),
                    child: TimeGutter(
                      habit.reminderTimeLabel ?? '',
                      width: 52,
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
