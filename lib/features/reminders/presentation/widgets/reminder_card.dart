import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/reminder.dart';

/// Rebuilt on [AppCard] like the habit, task and goal cards.
///
/// This was the one place in the app still using a raw Material `Card` with a
/// `ListTile` inside it, so it kept its own elevation and its own inset while
/// every list around it moved to the glass surface.
class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key, required this.reminder, this.onTap});

  final ReminderItem reminder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dueLabel = reminder.dueAt == null
        ? 'No time'
        : TimeOfDay.fromDateTime(reminder.dueAt!).format(context);
    final isDone = reminder.status == ReminderStatus.completed;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.notifications,
            color: isDone ? AppColors.deepGreen : AppColors.mutedBlue,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDone ? AppColors.subtleText : AppColors.charcoal,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (reminder.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reminder.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtleText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            dueLabel,
            style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
          ),
        ],
      ),
    );
  }
}
