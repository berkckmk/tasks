import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/reminder_providers.dart';
import 'widgets/reminder_card.dart';
import '../../../core/widgets/app_glass_app_bar.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../core/layout/scroll_insets.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppGlassAppBar(title: const Text('Reminders')),
      floatingActionButton: AppFab(
        onPressed: () => context.push('/reminders/new'),
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.notifications_outlined,
                  title: 'No reminders yet',
                  message: 'Use reminders to nudge the next action, so your habits and tasks stay on track.',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: scrollInsets(context),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final r = reminders[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ReminderCard(
                  reminder: r,
                  onTap: () => context.push('/reminders/${r.id}/edit'),
                ),
              );
            },
          );
        },
        error: (error, stack) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
