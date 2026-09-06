import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/layout/scroll_insets.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_fab.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../subscription/presentation/guarded_create.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';
import '../domain/habit_schedule.dart';
import 'widgets/habit_card.dart';

/// **Habits** — reached from More, with multi-selection support.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _startSelection(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Habit> habits) {
    setState(() {
      if (_selectedIds.length == habits.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(habits.map((h) => h.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Seçilen $count alışkanlık silinsin mi?',
      message: 'Bu işlem geri alınamaz.',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final toDelete = _selectedIds.toList();
    try {
      await Future.wait(
        toDelete.map(
          (id) => ref.read(habitActionsProvider).deleteHabit(id),
        ),
      );
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('$count alışkanlık silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Alışkanlıklar silinemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final habitsAsync = ref.watch(habitsProvider);
    final filter = ref.watch(habitFilterProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: _isSelectionMode
          ? null
          : AppFab(
              tooltip: 'Add habit',
              onPressed: () => GuardedCreate.habit(context, ref),
            ),
      body: habitsAsync.when(
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (habits) {
          final filtered = filter == null
              ? habits
              : habits.where((h) => h.category == filter).toList();

          final today = filtered.where((h) => h.isScheduledOn(now)).toList()
            ..sort(_byDoneThenName);
          final otherDays = filtered
              .where((h) => !h.isScheduledOn(now))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return ListView(
            padding: scrollInsets(context),
            children: [
              if (_isSelectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: c.edgeMd),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(AppIcons.x),
                        tooltip: 'Vazgeç',
                        onPressed: () => setState(() {
                          _selectedIds.clear();
                          _isSelectionMode = false;
                        }),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${_selectedIds.length} seçildi',
                        style: AppType.h5.copyWith(color: c.text),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _selectAll(filtered),
                        child: Text(
                          _selectedIds.length == filtered.length
                              ? 'Seçimi Kaldır'
                              : 'Tümünü Seç',
                          style: AppType.metaSmall.copyWith(color: c.accent),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(AppIcons.trash, color: Colors.redAccent),
                        tooltip: 'Seçilenleri Sil',
                        onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Text('Habits', style: AppType.h2.copyWith(color: c.text)),
                    const Spacer(),
                    if (filtered.isNotEmpty)
                      GhostIconButton(
                        icon: AppIcons.checkSquareOffset,
                        tooltip: 'Toplu seçim',
                        onPressed: () =>
                            setState(() => _isSelectionMode = true),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              _CategoryFilter(filter: filter),
              const SizedBox(height: AppSpacing.xl),
              if (filtered.isEmpty)
                EmptyState(
                  icon: AppIcons.plant,
                  title: filter == null
                      ? 'No habits yet'
                      : 'No ${filter.label.toLowerCase()} habits',
                  message: filter == null
                      ? 'Add your first habit to start building momentum.'
                      : 'Nothing in this category yet.',
                  actionLabel: 'Add habit',
                  onAction: () => GuardedCreate.habit(context, ref),
                )
              else ...[
                if (today.isNotEmpty)
                  _Group(
                    label: 'Today',
                    habits: today,
                    done: today.where((h) => h.isCompletedToday).length,
                    ref: ref,
                    isSelectionMode: _isSelectionMode,
                    selectedIds: _selectedIds,
                    onToggleSelect: _toggleSelect,
                    onStartSelection: _startSelection,
                  ),
                if (otherDays.isNotEmpty)
                  _Group(
                    label: 'Other days',
                    habits: otherDays,
                    ref: ref,
                    isSelectionMode: _isSelectionMode,
                    selectedIds: _selectedIds,
                    onToggleSelect: _toggleSelect,
                    onStartSelection: _startSelection,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static int _byDoneThenName(Habit a, Habit b) {
    if (a.isCompletedToday != b.isCompletedToday) {
      return a.isCompletedToday ? 1 : -1;
    }
    return a.name.compareTo(b.name);
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.habits,
    required this.ref,
    this.done,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.onStartSelection,
  });

  final String label;
  final List<Habit> habits;
  final WidgetRef ref;
  final int? done;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<String>? onStartSelection;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Kicker(label, color: c.muted),
              const Spacer(),
              if (done != null)
                Text(
                  '$done of ${habits.length} done',
                  style: AppType.meta.copyWith(color: c.inkAccent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                children: [
                  for (var i = 0; i < habits.length; i++)
                    HabitCard(
                      key: ValueKey(habits[i].id),
                      habit: habits[i],
                      isSelectionMode: isSelectionMode,
                      isSelected: selectedIds.contains(habits[i].id),
                      showDivider: i < habits.length - 1,
                      onToggle: () => ref
                          .read(habitActionsProvider)
                          .toggleCompletionToday(
                            habits[i].id,
                            habits[i].isCompletedToday,
                          ),
                      onSelect: () => onToggleSelect?.call(habits[i].id),
                      onLongPress: () {
                        if (!isSelectionMode) {
                          onStartSelection?.call(habits[i].id);
                        }
                      },
                      onTap: () {
                        if (isSelectionMode) {
                          onToggleSelect?.call(habits[i].id);
                        } else {
                          context.push('/habits/${habits[i].id}/edit');
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter({required this.filter});

  final HabitCategory? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(HabitCategory? value) =>
        ref.read(habitFilterProvider.notifier).state = value;

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            selected: filter == null,
            onTap: () => select(null),
          ),
          for (final category in HabitCategory.values)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _FilterChip(
                label: category.label,
                selected: filter == category,
                onTap: () => select(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final radius = BorderRadius.circular(AppSpacing.radiusSm);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? c.accentTint() : Colors.transparent,
        borderRadius: radius,
        border: Border.all(color: selected ? c.accentTint(0.40) : c.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: c.accentTint(0.14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Text(
                label,
                style: AppType.meta.copyWith(
                  fontSize: 12.5,
                  color: selected ? c.inkAccent : c.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
