import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../app/theme/app_colors.dart';

import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../application/workout_providers.dart';
import '../../domain/exercise_log.dart';

void showLogWorkoutSheet(BuildContext context, WidgetRef ref) {
  GlassModalSheet.show<void>(
    context: context,
    // Tall, but deliberately not `full`. GlassSheetState.full is documented
    // to transition to an opaque solid colour — at that stop the sheet stops
    // being glass at all, which is what the first version of this shipped: a
    // plain white panel over a glass app. Raising the half stop instead keeps
    // the material while still showing the whole form without a drag.
    halfSize: 0.78,
    initialState: GlassSheetState.half,
    // If the user does drag it to full, it fills with the app's cream rather
    // than the package's default white.
    expandedColor: AppColors.background,
    builder: (context) => Material(
      // GlassModalSheet wraps no Material — it is Cupertino all
      // the way down. Every one of these sheets contains a
      // TextField, which asserts on a missing Material ancestor,
      // so without this the sheet throws the moment it opens.
      // Transparency so the glass behind it still shows.
      type: MaterialType.transparency,
      child: const _LogWorkoutSheet(),
    ),
  );
}

class _ExerciseRowData {
  _ExerciseRowData()
    : nameController = TextEditingController(),
      setsController = TextEditingController(text: '3'),
      repsController = TextEditingController(text: '10'),
      weightController = TextEditingController(text: '0');

  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
  }
}

class _LogWorkoutSheet extends ConsumerStatefulWidget {
  const _LogWorkoutSheet();

  @override
  ConsumerState<_LogWorkoutSheet> createState() => _LogWorkoutSheetState();
}

class _LogWorkoutSheetState extends ConsumerState<_LogWorkoutSheet> {
  final _nameController = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_ExerciseRowData> _exercises = [_ExerciseRowData()];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
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
            Text('Log workout', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Workout name'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(DateFormat.yMMMd().format(_date)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Exercises', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ..._exercises.asMap().entries.map(
              (entry) => _exerciseRow(entry.key, entry.value),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _exercises.add(_ExerciseRowData())),
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _isSaving ? 'Saving...' : 'Save workout',
              expand: true,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseRow(int index, _ExerciseRowData row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.nameController,
              decoration: const InputDecoration(labelText: 'Exercise'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: row.setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sets'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: row.repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: row.weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'kg'),
            ),
          ),
          if (_exercises.length > 1)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                row.dispose();
                _exercises.removeAt(index);
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name')),
      );
      return;
    }

    final drafts = _exercises
        .where((e) => e.nameController.text.trim().isNotEmpty)
        .map(
          (e) => ExerciseDraft(
            name: e.nameController.text.trim(),
            sets: int.tryParse(e.setsController.text.trim()) ?? 0,
            reps: int.tryParse(e.repsController.text.trim()) ?? 0,
            weight: double.tryParse(e.weightController.text.trim()) ?? 0,
          ),
        )
        .toList();

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(workoutActionsProvider)
          .logWorkout(name: name, date: _date, exercises: drafts);
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't save workout: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
