import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/google_sync_status.dart';

/// Shared layout for every integration section on the Google Integrations
/// screen — icon/title, connected badge, permission explanation, last sync
/// row, and an Enable/Disable (or "Upgrade") action. [extra] slots in
/// integration-specific content (e.g. a spreadsheet link, an export button).
class IntegrationCard extends StatelessWidget {
  const IntegrationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.permissionExplanation,
    required this.locked,
    required this.enabled,
    required this.status,
    required this.lastSyncedAt,
    this.errorMessage,
    required this.isBusy,
    required this.onEnable,
    required this.onDisable,
    this.onUpgrade,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String permissionExplanation;
  final bool locked;
  final bool enabled;
  final GoogleSyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final bool isBusy;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback? onUpgrade;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final badgeColor = locked
        ? AppColors.subtleText
        : switch (status) {
            GoogleSyncStatus.connected => AppColors.deepGreen,
            GoogleSyncStatus.syncing => AppColors.mutedBlue,
            GoogleSyncStatus.error => AppColors.error,
            GoogleSyncStatus.notConnected => AppColors.subtleText,
          };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: badgeColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                ),
              ),
              AppBadge(
                label: locked ? 'Requires Complete' : status.label,
                color: badgeColor,
                icon: locked ? Icons.lock_outline : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            permissionExplanation,
            style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            lastSyncedAt == null
                ? 'Never synced'
                : 'Last synced ${DateFormat.yMMMd().add_jm().format(lastSyncedAt!)}',
            style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (locked)
                AppButton(
                  label: 'Upgrade to Complete',
                  icon: Icons.workspace_premium_outlined,
                  onPressed: onUpgrade,
                )
              else if (enabled) ...[
                AppButton(
                  label: isBusy ? 'Please wait...' : 'Disable',
                  variant: AppButtonVariant.secondary,
                  onPressed: isBusy ? null : onDisable,
                ),
              ] else
                AppButton(
                  label: isBusy ? 'Please wait...' : 'Enable',
                  onPressed: isBusy ? null : onEnable,
                ),
            ],
          ),
          if (extra != null && enabled && !locked) ...[
            const SizedBox(height: AppSpacing.sm),
            extra!,
          ],
        ],
      ),
    );
  }
}
