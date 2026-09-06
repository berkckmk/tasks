import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../application/finance_providers.dart';
import '../../domain/finance_transaction.dart';

void showAddTransactionSheet(BuildContext context, WidgetRef ref) {
  // A flat Nocturne panel over a dimmed ground. The three glass-specific
  // workarounds this block used to carry are all gone with the material:
  // there is no `full` stop that silently turns opaque, no `expandedColor`
  // to keep it from filling with the package's white, and no transparent
  // Material wrapper needed to satisfy the TextFields — showAppSheet is
  // Material all the way down.
  showAppSheet<void>(
    context: context,
    initialSize: 0.78,
    builder: (context) => const _AddTransactionSheet(),
  );
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = expenseCategories.first;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == TransactionType.income ? incomeCategories : expenseCategories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add transaction',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) => setState(() {
              _type = selection.first;
              _category = _categories.first;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: _categories
                .map(
                  (c) => ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save transaction',
            expand: true,
            onPressed: _isSaving
                ? null
                : () async {
                    final amount = double.tryParse(
                      _amountController.text.trim(),
                    );
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    try {
                      await ref
                          .read(financeActionsProvider)
                          .addTransaction(
                            type: _type,
                            amount: amount,
                            category: _category,
                            note: _noteController.text.trim(),
                            date: DateTime.now(),
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Couldn't save transaction: $e"),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
