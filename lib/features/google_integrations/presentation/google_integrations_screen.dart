import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/application/auth_actions.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/google_integrations_actions.dart';
import '../application/google_integrations_providers.dart';
import '../domain/google_integration_id.dart';
import '../domain/google_sync_status.dart';
import 'widgets/integration_card.dart';

class GoogleIntegrationsScreen extends ConsumerWidget {
  const GoogleIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Integrations')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: const [
          _GoogleAccountSection(),
          SizedBox(height: AppSpacing.lg),
          _CalendarSection(),
          SizedBox(height: AppSpacing.sm),
          _SheetsSection(),
          SizedBox(height: AppSpacing.sm),
          _DriveSection(),
          SizedBox(height: AppSpacing.sm),
          _DocsSection(),
        ],
      ),
    );
  }
}

class _GoogleAccountSection extends ConsumerStatefulWidget {
  const _GoogleAccountSection();

  @override
  ConsumerState<_GoogleAccountSection> createState() => _GoogleAccountSectionState();
}

class _GoogleAccountSectionState extends ConsumerState<_GoogleAccountSection> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final hasGoogleLinked = profileAsync.valueOrNull?.hasGoogleLinked ?? false;

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (hasGoogleLinked ? AppColors.deepGreen : AppColors.subtleText)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.account_circle_outlined,
              color: hasGoogleLinked ? AppColors.deepGreen : AppColors.subtleText,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Account',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                ),
                const SizedBox(height: 2),
                Text(
                  hasGoogleLinked
                      ? 'Connected — used to sign in faster and enable the integrations below.'
                      : 'Connect your Google account to sign in with Google and unlock the '
                          'integrations below.',
                  style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (_isBusy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (hasGoogleLinked)
            AppBadge(label: 'Connected', color: AppColors.deepGreen, icon: Icons.check_circle_outline)
          else
            AppButton(
              label: 'Connect',
              variant: AppButtonVariant.secondary,
              onPressed: () => _run(() => ref.read(authActionsProvider).linkGoogleAccount()),
            ),
        ],
      ),
    );
  }
}

class _CalendarSection extends ConsumerStatefulWidget {
  const _CalendarSection();

  @override
  ConsumerState<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends ConsumerState<_CalendarSection> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Calendar sync error: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(googleCalendarStatusProvider).valueOrNull;
    final locked = !ref.watch(planEnforcementProvider).canAccessGoogleIntegrations;
    final actions = ref.read(googleIntegrationsActionsProvider);

    return IntegrationCard(
      icon: Icons.event_outlined,
      title: GoogleIntegrationId.calendar.label,
      permissionExplanation: GoogleIntegrationId.calendar.permissionExplanation,
      locked: locked,
      enabled: status?.enabled ?? false,
      status: status?.status ?? GoogleSyncStatus.notConnected,
      lastSyncedAt: status?.lastSyncedAt,
      errorMessage: status?.errorMessage,
      isBusy: _isBusy,
      onUpgrade: () => context.push('/pricing'),
      onEnable: () => _run(() => actions.connect(GoogleIntegrationId.calendar)),
      onDisable: () => _run(() => actions.disconnect(GoogleIntegrationId.calendar)),
      extra: Align(
        alignment: Alignment.centerLeft,
        child: AppButton(
          label: 'Sync now',
          variant: AppButtonVariant.text,
          onPressed: _isBusy ? null : () => _run(actions.syncCalendarNow),
        ),
      ),
    );
  }
}

class _SheetsSection extends ConsumerStatefulWidget {
  const _SheetsSection();

  @override
  ConsumerState<_SheetsSection> createState() => _SheetsSectionState();
}

class _SheetsSectionState extends ConsumerState<_SheetsSection> {
  bool _isBusy = false;
  static const _allModules = [
    'Habits',
    'Habit Logs',
    'Tasks',
    'Goals',
    'Finance',
    'Workouts',
    'Learning',
    'Content',
  ];
  final Set<String> _selected = _allModules.toSet();

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export error: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(googleSheetsStatusProvider).valueOrNull;
    final locked = !ref.watch(planEnforcementProvider).canAccessGoogleIntegrations;
    final actions = ref.read(googleIntegrationsActionsProvider);

    return IntegrationCard(
      icon: Icons.table_chart_outlined,
      title: GoogleIntegrationId.sheets.label,
      permissionExplanation: GoogleIntegrationId.sheets.permissionExplanation,
      locked: locked,
      enabled: status?.enabled ?? false,
      status: status?.status ?? GoogleSyncStatus.notConnected,
      lastSyncedAt: status?.lastExportedAt,
      errorMessage: status?.errorMessage,
      isBusy: _isBusy,
      onUpgrade: () => context.push('/pricing'),
      onEnable: () => _run(() => actions.connect(GoogleIntegrationId.sheets)),
      onDisable: () => _run(() => actions.disconnect(GoogleIntegrationId.sheets)),
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            children: _allModules
                .map(
                  (m) => FilterChip(
                    label: Text(m, style: const TextStyle(fontSize: 11)),
                    selected: _selected.contains(m),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _selected.add(m);
                      } else {
                        _selected.remove(m);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppButton(
                label: 'Export now',
                variant: AppButtonVariant.text,
                onPressed: _isBusy || _selected.isEmpty
                    ? null
                    : () => _run(() => actions.exportToSheets(_selected.toList())),
              ),
              if (status?.spreadsheetUrl != null)
                AppButton(
                  label: 'Open spreadsheet',
                  variant: AppButtonVariant.text,
                  icon: Icons.open_in_new,
                  onPressed: () => launchUrl(Uri.parse(status!.spreadsheetUrl!)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriveSection extends ConsumerStatefulWidget {
  const _DriveSection();

  @override
  ConsumerState<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends ConsumerState<_DriveSection> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup error: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(googleDriveStatusProvider).valueOrNull;
    final locked = !ref.watch(planEnforcementProvider).canAccessGoogleIntegrations;
    final actions = ref.read(googleIntegrationsActionsProvider);

    return IntegrationCard(
      icon: Icons.folder_outlined,
      title: GoogleIntegrationId.drive.label,
      permissionExplanation: GoogleIntegrationId.drive.permissionExplanation,
      locked: locked,
      enabled: status?.enabled ?? false,
      status: status?.status ?? GoogleSyncStatus.notConnected,
      lastSyncedAt: status?.lastBackupAt,
      errorMessage: status?.errorMessage,
      isBusy: _isBusy,
      onUpgrade: () => context.push('/pricing'),
      onEnable: () => _run(() => actions.connect(GoogleIntegrationId.drive)),
      onDisable: () => _run(() => actions.disconnect(GoogleIntegrationId.drive)),
      extra: Row(
        children: [
          AppButton(
            label: 'Back up now',
            variant: AppButtonVariant.text,
            onPressed: _isBusy ? null : () => _run(actions.backupToDrive),
          ),
          if (status?.folderUrl != null)
            AppButton(
              label: 'Open folder',
              variant: AppButtonVariant.text,
              icon: Icons.open_in_new,
              onPressed: () => launchUrl(Uri.parse(status!.folderUrl!)),
            ),
        ],
      ),
    );
  }
}

class _DocsSection extends ConsumerStatefulWidget {
  const _DocsSection();

  @override
  ConsumerState<_DocsSection> createState() => _DocsSectionState();
}

class _DocsSectionState extends ConsumerState<_DocsSection> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(const SnackBar(content: Text('Report generated — see Reports.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Report error: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(googleDocsStatusProvider).valueOrNull;
    final locked = !ref.watch(planEnforcementProvider).canAccessGoogleIntegrations;
    final actions = ref.read(googleIntegrationsActionsProvider);

    return IntegrationCard(
      icon: Icons.description_outlined,
      title: GoogleIntegrationId.docs.label,
      permissionExplanation: GoogleIntegrationId.docs.permissionExplanation,
      locked: locked,
      enabled: status?.enabled ?? false,
      status: status?.status ?? GoogleSyncStatus.notConnected,
      lastSyncedAt: status?.lastReportGeneratedAt,
      errorMessage: status?.errorMessage,
      isBusy: _isBusy,
      onUpgrade: () => context.push('/pricing'),
      onEnable: () => _run(() => actions.connect(GoogleIntegrationId.docs)),
      onDisable: () => _run(() => actions.disconnect(GoogleIntegrationId.docs)),
      extra: Align(
        alignment: Alignment.centerLeft,
        child: AppButton(
          label: 'Generate weekly report',
          variant: AppButtonVariant.text,
          onPressed: _isBusy
              ? null
              : () => _run(
                    () => actions.generateReport(
                      type: 'weekly',
                      periodStart: DateTime.now().subtract(const Duration(days: 7)),
                      periodEnd: DateTime.now(),
                    ),
                  ),
        ),
      ),
    );
  }
}
