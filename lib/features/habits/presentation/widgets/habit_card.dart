import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/habit.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.onToggle,
    this.onTap,
  });

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: habit.isCompletedToday ? habit.color : Colors.transparent,
                border: Border.all(color: habit.color, width: 2),
              ),
              child: habit.isCompletedToday
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppBadge(label: habit.category.label, color: habit.color),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      habit.frequencyLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department, size: 16, color: AppColors.amber),
              const SizedBox(width: 2),
              Text(
                '${habit.streak}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
