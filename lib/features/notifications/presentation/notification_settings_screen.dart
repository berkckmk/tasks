import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_glass_app_bar.dart';
import '../../profile/application/profile_providers.dart';
import '../application/notification_settings_providers.dart';
import '../domain/notification_settings.dart';

/// Per-channel notification settings.
///
/// Each switch here gates a real scheduled function in
/// `functions/src/notifications/reminders.ts`; nothing on this screen is
/// decorative.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final busy = ref.watch(notificationPermissionBusyProvider);
    final actions = ref.read(notificationSettingsActionsProvider);
    final timezone = ref.watch(profileProvider).valueOrNull?.timezone ?? '';

    return Scaffold(
      appBar: const AppGlassAppBar(title: Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.deepGreen,
              title: const Text(
                'Allow notifications',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Turn everything off without losing the choices below.',
              ),
              value: settings.masterEnabled,
              onChanged: busy
                  ? null
                  : (value) async {
                      final granted = await actions.setMasterEnabled(value);
                      if (!granted && value && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notification permission was denied in system settings.',
                            ),
                          ),
                        );
                      }
                    },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('What you get'),
          for (final channel in NotificationChannel.values) ...[
            AppCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.deepGreen,
                    title: Text(
                      channel.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(channel.description),
                    value: settings.isChannelOn(channel),
                    // Left visibly on but inert while the master switch is
                    // off, rather than flipped off: the stored choice is
                    // unchanged, and flipping them would lose it.
                    onChanged: settings.masterEnabled
                        ? (value) => actions.setChannel(channel, value)
                        : null,
                  ),
                  if (channel == NotificationChannel.taskDigest)
                    _DigestHourRow(
                      hour: settings.taskDigestHour,
                      enabled: settings.isEnabled(channel),
                      onChanged: actions.setTaskDigestHour,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          _TimeZoneNote(timezone: timezone),
        ],
      ),
    );
  }
}

/// Picks the hour the daily digest arrives.
///
/// An hour and not a time: the backend pass that sends it runs hourly, so a
/// minute component would be a promise the scheduler can't keep.
class _DigestHourRow extends StatelessWidget {
  const _DigestHourRow({
    required this.hour,
    required this.enabled,
    required this.onChanged,
  });

  final int hour;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 18,
            color: enabled ? AppColors.subtleText : AppColors.divider,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Send at',
              style: TextStyle(
                color: enabled ? AppColors.charcoal : AppColors.subtleText,
              ),
            ),
          ),
          DropdownButton<int>(
            value: hour,
            underline: const SizedBox.shrink(),
            onChanged: enabled
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(
                  value: h,
                  child: Text('${h.toString().padLeft(2, '0')}:00'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// States which clock these times are read against.
///
/// Not decoration. Every schedule here is evaluated in the user's own IANA
/// zone by the backend, and that zone comes from a field on their profile
/// that is repaired on each cold start. Showing it makes a wrong value
/// visible instead of leaving "my digest arrives at the wrong hour" as a
/// mystery — the failure this whole timezone layer exists for.
class _TimeZoneNote extends StatelessWidget {
  const _TimeZoneNote({required this.timezone});

  final String timezone;

  @override
  Widget build(BuildContext context) {
    final zone = timezone.isEmpty ? 'not detected yet' : timezone;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.public, size: 16, color: AppColors.subtleText),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Times are your local times — $zone.',
            style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.deepGreen,
        ),
      ),
    );
  }
}
