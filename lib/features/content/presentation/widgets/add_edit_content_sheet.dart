import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../application/content_providers.dart';
import '../../domain/content_item.dart';

void showAddEditContentSheet(BuildContext context, WidgetRef ref, {ContentItem? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
    ),
    builder: (context) => _AddEditContentSheet(existing: existing),
  );
}

class _AddEditContentSheet extends ConsumerStatefulWidget {
  const _AddEditContentSheet({this.existing});

  final ContentItem? existing;

  @override
  ConsumerState<_AddEditContentSheet> createState() => _AddEditContentSheetState();
}

class _AddEditContentSheetState extends ConsumerState<_AddEditContentSheet> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late String _platform = widget.existing?.platform ?? contentPlatforms.first;
  late ContentStatus _status = widget.existing?.status ?? ContentStatus.idea;
  DateTime? _publishDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _publishDate = widget.existing?.publishDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add content idea' : 'Edit content idea',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Platform', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: contentPlatforms
                  .map(
                    (p) => ChoiceChip(
                      label: Text(p),
                      selected: _platform == p,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _platform = p),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: ContentStatus.values
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
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _publishDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _publishDate = picked);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _publishDate == null
                    ? 'Set a publish date (optional)'
                    : DateFormat.yMMMd().format(_publishDate!),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(contentActionsProvider).saveItem(
            id: widget.existing?.id,
            title: title,
            platform: _platform,
            publishDate: _publishDate,
            status: _status,
          );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
