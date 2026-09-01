import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../application/finance_providers.dart';
import '../../domain/savings_goal.dart';

void showSavingsGoalSheet(
  BuildContext context,
  WidgetRef ref, {
  SavingsGoal? existing,
}) {
  // A flat Nocturne panel over a dimmed ground. The three glass-specific
  // workarounds this block used to carry are all gone with the material:
  // there is no `full` stop that silently turns opaque, no `expandedColor`
  // to keep it from filling with the package's white, and no transparent
  // Material wrapper needed to satisfy the TextFields — showAppSheet is
  // Material all the way down.
  showAppSheet<void>(
    context: context,
    initialSize: 0.78,
    builder: (context) => _SavingsGoalSheet(existing: existing),
  );
}

class _SavingsGoalSheet extends ConsumerStatefulWidget {
  const _SavingsGoalSheet({this.existing});

  final SavingsGoal? existing;

  @override
  ConsumerState<_SavingsGoalSheet> createState() => _SavingsGoalSheetState();
}

class _SavingsGoalSheetState extends ConsumerState<_SavingsGoalSheet> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  // toStringAsFixed(2), not (0): seeding these inputs with a rounded value
  // meant simply opening an existing savings goal and saving it again
  // silently discarded the cents.
  late final _targetController = TextEditingController(
    text: widget.existing?.targetAmount.toStringAsFixed(2) ?? '',
  );
  late final _currentController = TextEditingController(
    text: widget.existing?.currentAmount.toStringAsFixed(2) ?? '0',
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Savings goal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Goal title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target amount',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _currentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Saved so far',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _isSaving ? 'Saving...' : 'Save goal',
            expand: true,
            onPressed: _isSaving
                ? null
                : () async {
                    final title = _titleController.text.trim();
                    final target = double.tryParse(
                      _targetController.text.trim(),
                    );
                    final current =
                        double.tryParse(_currentController.text.trim()) ?? 0;
                    if (title.isEmpty || target == null || target <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a title and a target amount'),
                        ),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    try {
                      await ref
                          .read(financeActionsProvider)
                          .saveSavingsGoal(
                            id: widget.existing?.id,
                            title: title,
                            targetAmount: target,
                            currentAmount: current,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Couldn't save goal: $e")),
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
