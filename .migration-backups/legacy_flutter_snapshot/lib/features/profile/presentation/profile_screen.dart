import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/layout/scroll_insets.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../auth/application/auth_actions.dart';
import '../../notifications/application/notification_settings_providers.dart';
import '../../notifications/domain/notification_settings.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../application/avatar_actions.dart';
import '../application/profile_providers.dart';
import '../domain/user_profile.dart';

/// One line describing the notification setup, for the row that opens the
/// settings screen — so the common case (nothing changed) doesn't require
/// opening it to check.
String _notificationSummary(NotificationSettings settings) {
  if (!settings.masterEnabled) return 'Off';
  final on = NotificationChannel.values.where(settings.isEnabled).length;
  if (on == NotificationChannel.values.length) return 'All notifications on';
  if (on == 0) return 'No types selected';
  return '$on of ${NotificationChannel.values.length} types on';
}

/// **Profile** — `2b`: a flush-left identity block, a three-column stat strip,
/// and setting rows separated by Nocturne's fading rule.
///
/// Reached from More now rather than from a bottom tab. The header lockup sits
/// at the very top, as it does in all three directions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final currentPlan = ref.watch(currentPlanProvider);
    final enforcement = ref.watch(planEnforcementProvider);
    final notificationSummary = _notificationSummary(
      ref.watch(notificationSettingsProvider),
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppTopBar(
        actions: [
          GhostIconButton(
            icon: AppIcons.signOut,
            tooltip: 'Log out',
            onPressed: () => ref.read(authActionsProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Setting up your account…',
                  style: AppType.bodySmall.copyWith(color: c.muted),
                ),
              ),
            );
          }

          final displayName = profile.displayName.isNotEmpty
              ? profile.displayName
              : profile.email;

          return ListView(
            padding: scrollInsets(context),
            children: [
              BrandLockup(subtitle: '${currentPlan.name} plan · beta'),
              const SizedBox(height: AppSpacing.xl),

              // Flush left — no card. The avatar, the name and the plan badge
              // are the identity; boxing them adds an edge that separates them
              // from a screen they are the top of.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AvatarPicker(profile: profile, displayName: displayName),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppType.h3.copyWith(color: c.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.email,
                          style: AppType.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: AppBadge(label: '${currentPlan.name} plan'),
              ),

              const SizedBox(height: AppSpacing.xl),
              const _StatStrip(),
              const SizedBox(height: AppSpacing.xl),

              _SettingRow(
                icon: AppIcons.bell,
                title: 'Reminders & nudges',
                // The row opens the settings screen rather than carrying a
                // single on/off switch, because there is more than one thing
                // to decide: each channel has its own switch and the digest
                // has a send time.
                subtitle: notificationSummary,
                onTap: () => context.push('/settings/notifications'),
              ),
              _SettingRow(
                icon: AppIcons.googleLogo,
                title: 'Calendar, Sheets, Drive & Docs',
                subtitle: enforcement.canAccessGoogleIntegrations
                    ? (profile.hasGoogleLinked
                          ? 'Manage your connected Google integrations'
                          : 'Connect your Google account to get started')
                    : 'Part of the Complete plan',
                onTap: () => context.push('/google-integrations'),
              ),
              _SettingRow(
                icon: AppIcons.downloadSimple,
                title: 'Export data',
                subtitle: 'Coming soon',
                onTap: null,
                last: true,
              ),

              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Manage plan',
                expand: true,
                onPressed: () => context.push('/pricing'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Three numbers, flush, no tiles.
///
/// **The third stat is not the mock's "86% on time."** That number needs to
/// know *when* a reminder was completed, and the reminder document has no
/// `completedAt` — only a `status`. There is nothing to compute it from, and
/// inventing one would be a made-up statistic on the user's own profile. Tasks
/// completed is a real count from data that exists; adding `completedAt` to
/// the reminder write path would be a data-model change, which this redesign
/// explicitly is not.
class _StatStrip extends ConsumerWidget {
  const _StatStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(analyticsSummaryProvider).valueOrNull;
    final reminders = ref.watch(remindersProvider).valueOrNull ?? const [];
    final tasks = ref.watch(tasksProvider).valueOrNull ?? const [];

    final streak = summary?.bestStreak ?? 0;
    final remindersDone = reminders
        .where((r) => r.status == ReminderStatus.completed)
        .length;
    final tasksDone = tasks.where((t) => t.isDone).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Stat(value: '$streak', label: 'day streak')),
        Expanded(
          child: _Stat(value: '$remindersDone', label: 'reminders completed'),
        ),
        Expanded(child: _Stat(value: '$tasksDone', label: 'tasks completed')),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppType.numeral.copyWith(color: c.text)),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Text(
            label,
            style: AppType.metaSmall.copyWith(color: c.caption),
          ),
        ),
      ],
    );
  }
}

/// A setting row, separated from the next by the fading rule rather than by a
/// card edge.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: c.accentTint(0.10),
              highlightColor: c.accentTint(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: c.muted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppType.title.copyWith(color: c.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppType.note.copyWith(color: c.note),
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      Icon(
                        AppIcons.caretRight,
                        size: 14,
                        color: c.chevron,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!last) const FadingRule(),
        ],
      ),
    );
  }
}

class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker({required this.profile, required this.displayName});

  final UserProfile profile;
  final String displayName;

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  bool _isUploading = false;

  Future<void> _pick() async {
    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(avatarActionsProvider).pickAndUploadAvatar();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't upload photo: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final photoUrl = widget.profile.photoUrl;

    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: _isUploading ? null : _pick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 56px, an accent-tinted ground and a 1px accent border — the
            // accent as an edge, not as a filled disc.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.accentTint(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: c.accent),
                image: photoUrl == null
                    ? null
                    : DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: _isUploading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: c.accent,
                      ),
                    )
                  : photoUrl != null
                  ? null
                  : Text(
                      widget.displayName.isNotEmpty
                          ? widget.displayName[0].toUpperCase()
                          : '?',
                      style: AppType.h3.copyWith(color: c.inkAccent),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.divider),
                ),
                child: Icon(
                  AppIcons.pencilSimple,
                  size: 10,
                  color: c.inkAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
