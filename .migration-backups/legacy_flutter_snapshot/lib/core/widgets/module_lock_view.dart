import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';
import 'app_badge.dart';
import 'app_button.dart';
import '../../core/constants/app_icons.dart';

/// The "upgrade gate" shown in place of a locked screen/module: explains
/// the benefit, names the plan that unlocks it, and offers a CTA straight
/// to the pricing screen.
class ModuleLockView extends StatelessWidget {
  const ModuleLockView({
    super.key,
    required this.featureName,
    required this.benefit,
    required this.requiredPlanName,
    this.icon = AppIcons.lockSimple,
  });

  final String featureName;
  final String benefit;
  final String requiredPlanName;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.amber),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              featureName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              benefit,
              style: const TextStyle(color: AppColors.subtleText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppBadge(
              label: 'Requires $requiredPlanName',
              color: AppColors.amber,
              icon: AppIcons.sparkle,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Upgrade to $requiredPlanName',
              icon: AppIcons.sparkle,
              onPressed: () => context.push('/pricing'),
            ),
          ],
        ),
      ),
    );
  }
}
