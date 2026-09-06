import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../application/learning_providers.dart';
import '../../domain/learning_item.dart';
import '../../../../core/constants/app_icons.dart';

void showAddEditLearningSheet(
  BuildContext context,
  WidgetRef ref, {
  LearningItem? existing,
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
    builder: (context) => _AddEditLearningSheet(existing: existing),
  );
}

class _AddEditLearningSheet extends ConsumerStatefulWidget {
  const _AddEditLearningSheet({this.existing});

  final LearningItem? existing;

  @override
  ConsumerState<_AddEditLearningSheet> createState() =>
      _AddEditLearningSheetState();
}

class _AddEditLearningSheetState extends ConsumerState<_AddEditLearningSheet> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.existing?.notes ?? '',
  );
  late final _takeawaysController = TextEditingController(
    text: widget.existing?.keyTakeaways.join('\n') ?? '',
  );
  late LearningType _type = widget.existing?.type ?? LearningType.book;
  late LearningStatus _status =
      widget.existing?.status ?? LearningStatus.planned;
  late int _rating = widget.existing?.rating ?? 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _takeawaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? 'Add learning item'
                  : 'Edit learning item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: LearningType.values
                  .map(
                    (t) => ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: LearningStatus.values
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Rating', style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  icon: Icon(
                    filled ? AppIcons.starFill : AppIcons.star,
                    color: AppColors.amber,
                  ),
                  onPressed: () => setState(() => _rating = i + 1),
                );
              }),
            ),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _takeawaysController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Key takeaways (one per line)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _isSaving ? 'Saving...' : 'Save',
              expand: true,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final takeaways = _takeawaysController.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      await ref
          .read(learningActionsProvider)
          .saveItem(
            id: widget.existing?.id,
            title: title,
            type: _type,
            status: _status,
            rating: _rating,
            notes: _notesController.text.trim(),
            keyTakeaways: takeaways,
          );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
