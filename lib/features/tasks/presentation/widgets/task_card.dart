import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/task_item.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleDone,
    this.onTap,
  });

  final TaskItem task;
  final VoidCallback onToggleDone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleDone,
            child: Icon(
              task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.isDone ? AppColors.deepGreen : AppColors.subtleText,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: task.isDone ? AppColors.subtleText : AppColors.charcoal,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.MMMd().format(task.dueDate!),
                    style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                  ),
                ],
              ],
            ),
          ),
          AppBadge(label: task.priority.label, color: task.priority.color),
        ],
      ),
    );
  }
}
