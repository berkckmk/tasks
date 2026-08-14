import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A circular progress indicator with the percentage rendered in the center.
/// Used for "today's progress" on the dashboard and goal progress.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 8,
    this.color = AppColors.deepGreen,
    this.label,
  });

  /// 0.0 - 1.0
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: strokeWidth,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            label ?? '${(clamped * 100).round()}%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
