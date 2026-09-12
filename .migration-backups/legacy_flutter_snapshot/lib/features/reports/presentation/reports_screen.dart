import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/reports_providers.dart';
import '../domain/report.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/constants/app_icons.dart';

const _statusColors = {
  ReportStatus.pending: AppColors.subtleText,
  ReportStatus.generating: AppColors.mutedBlue,
  ReportStatus.ready: AppColors.deepGreen,
  ReportStatus.failed: AppColors.error,
};

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref
        .watch(planEnforcementProvider)
        .canAccessGoogleIntegrations;

    if (!canAccess) {
      return Scaffold(
        appBar: AppTopBar(title: const Text('Reports')),
        body: const ModuleLockView(
          featureName: 'Progress reports',
          benefit:
              'Generate a Google Docs report summarizing your habits, tasks, goals, and '
              'more — with reflection prompts included.',
          requiredPlanName: 'Complete',
          icon: AppIcons.fileText,
        ),
      );
    }

    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppTopBar(title: const Text('Reports')),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return const EmptyState(
              icon: AppIcons.fileText,
              title: 'No reports yet',
              message: 'Generate one from Google Integrations > Google Docs Reports.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _ReportTile(report: reports[index]),
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: report.googleDocUrl == null
          ? null
          : () => launchUrl(Uri.parse(report.googleDocUrl!)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.type.label} report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat.MMMd().format(report.periodStart)} - '
                  '${DateFormat.MMMd().format(report.periodEnd)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtleText,
                  ),
                ),
              ],
            ),
          ),
          AppBadge(
            label: report.status.label,
            color: _statusColors[report.status] ?? AppColors.subtleText,
          ),
          if (report.googleDocUrl != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              AppIcons.arrowSquareOut,
              size: 16,
              color: AppColors.subtleText,
            ),
          ],
        ],
      ),
    );
  }
}
