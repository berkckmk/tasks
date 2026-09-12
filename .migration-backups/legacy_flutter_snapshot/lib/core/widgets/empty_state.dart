import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';
import 'app_button.dart';

/// Shown wherever a list has no items yet.
///
/// The tinted circle behind the icon is gone — a filled disc of accent is a
/// flood, and an empty screen is the last place that should be the loudest
/// thing on it. What is left is the glyph at 35%, a 16px title and a 13px
/// line, which is the same treatment the widget's own empty state uses.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: c.text.withValues(alpha: 0.35)),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppType.title.copyWith(fontSize: 16, color: c.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppType.caption.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
