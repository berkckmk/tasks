import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/content_providers.dart';
import '../domain/content_item.dart';
import 'widgets/add_edit_content_sheet.dart';

const _statusColors = {
  ContentStatus.idea: AppColors.subtleText,
  ContentStatus.drafted: AppColors.mutedBlue,
  ContentStatus.scheduled: AppColors.amber,
  ContentStatus.published: AppColors.deepGreen,
};

class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(planEnforcementProvider).canAccessContentPlanner;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Content planner')),
        body: const ModuleLockView(
          featureName: 'Content planner',
          benefit: 'Plan content ideas across platforms, from idea to published, in one '
              'place.',
          requiredPlanName: 'Complete',
          icon: Icons.edit_calendar_outlined,
        ),
      );
    }

    final itemsAsync = ref.watch(contentItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Content planner')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'contentFab',
        onPressed: () => showAddEditContentSheet(context, ref),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.edit_calendar_outlined,
              title: 'No content ideas yet',
              message: 'Add your first idea to start planning your content calendar.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _ContentTile(item: items[index]),
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ContentTile extends ConsumerWidget {
  const _ContentTile({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => showAddEditContentSheet(context, ref, existing: item),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppBadge(label: item.platform, color: AppColors.mutedBlue),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(
                      label: item.status.label,
                      color: _statusColors[item.status] ?? AppColors.subtleText,
                    ),
                    if (item.publishDate != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        DateFormat.MMMd().format(item.publishDate!),
                        style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.subtleText),
            onPressed: () => ref.read(contentActionsProvider).deleteItem(item.id),
          ),
        ],
      ),
    );
  }
}
