import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/finance_providers.dart';
import '../domain/finance_transaction.dart';
import '../domain/savings_goal.dart';
import 'widgets/add_transaction_sheet.dart';
import 'widgets/savings_goal_sheet.dart';

final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(planEnforcementProvider).canAccessFinanceTracker;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finance tracker')),
        body: const ModuleLockView(
          featureName: 'Finance tracker',
          benefit: 'Log income and expenses, track a savings goal, and see your monthly '
              'savings rate at a glance.',
          requiredPlanName: 'Complete',
          icon: Icons.savings_outlined,
        ),
      );
    }

    final transactionsAsync = ref.watch(financeTransactionsProvider);
    final savingsGoalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance tracker')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'financeFab',
        onPressed: () => showAddTransactionSheet(context, ref),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final now = DateTime.now();
          final thisMonth = transactions.where(
            (t) => t.date.year == now.year && t.date.month == now.month,
          );
          final income = thisMonth
              .where((t) => t.type == TransactionType.income)
              .fold<double>(0, (sum, t) => sum + t.amount);
          final expenses = thisMonth
              .where((t) => t.type == TransactionType.expense)
              .fold<double>(0, (sum, t) => sum + t.amount);
          final savingsRate = income <= 0 ? 0.0 : ((income - expenses) / income).clamp(-1.0, 1.0);

          final savingsGoals = savingsGoalsAsync.valueOrNull ?? const <SavingsGoal>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              Text('This month', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.trending_up,
                      label: 'Income',
                      value: _currencyFormat.format(income),
                      accentColor: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.trending_down,
                      label: 'Expenses',
                      value: _currencyFormat.format(expenses),
                      accentColor: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.percent,
                      label: 'Savings rate',
                      value: '${(savingsRate * 100).round()}%',
                      accentColor: AppColors.mutedBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Income vs. expenses',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.deepGreen.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Charts coming soon',
                        style: TextStyle(color: AppColors.subtleText, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Savings goal', style: Theme.of(context).textTheme.titleSmall),
                  AppButton(
                    label: savingsGoals.isEmpty ? 'Set a goal' : 'Edit',
                    variant: AppButtonVariant.text,
                    onPressed: () => showSavingsGoalSheet(
                      context,
                      ref,
                      existing: savingsGoals.isEmpty ? null : savingsGoals.first,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (savingsGoals.isEmpty)
                const AppCard(
                  child: Text(
                    'No savings goal yet. Set one to track progress here.',
                    style: TextStyle(color: AppColors.subtleText, fontSize: 13),
                  ),
                )
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        savingsGoals.first.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: savingsGoals.first.progress.toDouble(),
                          minHeight: 8,
                          backgroundColor: AppColors.deepGreen.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.deepGreen),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${_currencyFormat.format(savingsGoals.first.currentAmount)} of '
                        '${_currencyFormat.format(savingsGoals.first.targetAmount)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text('Recent transactions', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              if (transactions.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  message: 'Log your first income or expense to get started.',
                )
              else
                ...transactions.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TransactionTile(transaction: t),
                  ),
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

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type == TransactionType.income;
    return AppCard(
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? AppColors.deepGreen : AppColors.error,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
                ),
                Text(
                  DateFormat.MMMd().format(transaction.date),
                  style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.deepGreen : AppColors.error,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.subtleText),
            onPressed: () => ref.read(financeActionsProvider).deleteTransaction(transaction.id),
          ),
        ],
      ),
    );
  }
}
