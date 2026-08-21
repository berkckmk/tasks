import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../auth/application/auth_actions.dart';
import '../../notifications/application/notification_settings_providers.dart';
import '../../notifications/domain/notification_settings.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/avatar_actions.dart';
import '../application/profile_providers.dart';
import '../domain/user_profile.dart';
import '../../../core/widgets/app_glass_app_bar.dart';
import '../../../core/layout/scroll_insets.dart';

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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final currentPlan = ref.watch(currentPlanProvider);
    final enforcement = ref.watch(planEnforcementProvider);
    final notificationSummary = _notificationSummary(
      ref.watch(notificationSettingsProvider),
    );

    return Scaffold(
      appBar: AppGlassAppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authActionsProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Setting up your account...',
                  style: TextStyle(color: AppColors.subtleText),
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
              AppCard(
                child: Row(
                  children: [
                    _AvatarPicker(profile: profile, displayName: displayName),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.subtleText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppBadge(
                            label: '${currentPlan.name} plan',
                            color: AppColors.deepGreen,
                            icon: Icons.workspace_premium_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Notifications'),
              // Was a single on/off switch here. It now opens the settings
              // screen instead, because there is more than one thing to
              // decide: each channel has its own switch and the digest has a
              // send time. The permission + token handling that used to live
              // in this callback moved to NotificationSettingsActions.
              AppCard(
                onTap: () => context.push('/settings/notifications'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      color: AppColors.subtleText,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reminders & nudges',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notificationSummary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.subtleText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.subtleText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Google integrations'),
              AppCard(
                onTap: () => context.push('/google-integrations'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      color: AppColors.subtleText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Calendar, Sheets, Drive & Docs'),
                          Text(
                            enforcement.canAccessGoogleIntegrations
                                ? (profile.hasGoogleLinked
                                      ? 'Manage your connected Google integrations'
                                      : 'Connect your Google account to get started')
                                : 'Part of the Complete plan',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.subtleText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.subtleText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Data'),
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.download_outlined,
                      color: AppColors.subtleText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(child: Text('Export data')),
                    AppButton(
                      label: 'Coming soon',
                      variant: AppButtonVariant.text,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Upgrade plan',
                icon: Icons.workspace_premium_outlined,
                expand: true,
                onPressed: () => context.push('/pricing'),
              ),
            ],
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
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
    final photoUrl = widget.profile.photoUrl;
    return GestureDetector(
      onTap: _isUploading ? null : _pick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.deepGreen.withValues(alpha: 0.12),
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : photoUrl != null
                ? null
                : Text(
                    widget.displayName.isNotEmpty
                        ? widget.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.deepGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.subtleText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
