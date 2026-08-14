import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/goal.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap});

  final Goal goal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                ),
              ),
              AppBadge(label: goal.category.label, color: AppColors.mutedBlue),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.deepGreen.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.deepGreen),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(goal.progress * 100).round()}% complete',
                style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
              ),
              if (goal.targetDate != null)
                Text(
                  'Due ${DateFormat.MMMd().format(goal.targetDate!)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
