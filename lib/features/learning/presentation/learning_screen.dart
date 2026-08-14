import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/learning_providers.dart';
import '../domain/learning_item.dart';
import 'widgets/add_edit_learning_sheet.dart';

class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(planEnforcementProvider).canAccessLearningTracker;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning tracker')),
        body: const ModuleLockView(
          featureName: 'Learning tracker',
          benefit: 'Track books, courses, and podcasts — with ratings, notes, and key '
              'takeaways you can look back on.',
          requiredPlanName: 'Complete',
          icon: Icons.menu_book_outlined,
        ),
      );
    }

    final itemsAsync = ref.watch(learningItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Learning tracker')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'learningFab',
        onPressed: () => showAddEditLearningSheet(context, ref),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Nothing here yet',
              message: 'Add a book, course, or podcast to start tracking what you learn.',
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
            itemBuilder: (context, index) {
              final item = items[index];
              return _LearningTile(item: item);
            },
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _LearningTile extends ConsumerWidget {
  const _LearningTile({required this.item});

  final LearningItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => showAddEditLearningSheet(context, ref, existing: item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.subtleText),
                onPressed: () => ref.read(learningActionsProvider).deleteItem(item.id),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              AppBadge(label: item.type.label, color: AppColors.mutedBlue),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(label: item.status.label, color: AppColors.deepGreen),
              const Spacer(),
              if (item.rating > 0)
                Row(
                  children: List.generate(
                    item.rating,
                    (_) => const Icon(Icons.star, size: 14, color: AppColors.amber),
                  ),
                ),
            ],
          ),
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.subtleText),
            ),
          ],
        ],
      ),
    );
  }
}
