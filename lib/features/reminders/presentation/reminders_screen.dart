import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/nocturne.dart';
import '../../../core/widgets/app_fab.dart';
import '../../subscription/presentation/guarded_create.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder.dart';
import 'widgets/reminder_card.dart';

/// **Reminders** — `2b` Rail, the rail flattened into three groups.
///
/// Tab 0, and where a cold start lands. Each group is headed by a 34/500
/// tabular numeral beside its kicker, so the shape of the day is legible
/// before a single row is read. **Overdue carries a 2px accent left border**;
/// the other two take a 1px divider border — the accent as a line, marking the
/// one group that needs attention.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String _query = '';
  bool _searching = false;
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

  void _selectAll(List<ReminderItem> all) {
    setState(() {
      if (_selectedIds.length == all.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(all.map((r) => r.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Seçilen $count hatırlatıcı silinsin mi?',
      message: 'Bu işlem geri alınamaz.',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final toDelete = _selectedIds.toList();
    try {
      await Future.wait(
        toDelete.map(
          (id) => ref.read(reminderActionsProvider).deleteReminder(id),
        ),
      );
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('$count hatırlatıcı silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Hatırlatıcılar silinemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: _isSelectionMode
          ? null
          : AppFab(
              tooltip: 'Add reminder',
              onPressed: () => GuardedCreate.reminder(context, ref),
            ),
      body: SafeArea(
        bottom: false,
        child: remindersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(error: error),
          data: (reminders) => _body(context, reminders),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<ReminderItem> all) {
    final c = AppColorsScheme.of(context);
    final now = DateTime.now();
    final groups = _group(all, now);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xl,
      ),
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
                  onPressed: () => _selectAll(all),
                  child: Text(
                    _selectedIds.length == all.length
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
              Text('Reminders', style: AppType.h2.copyWith(color: c.text)),
              const Spacer(),
              if (all.isNotEmpty)
                GhostIconButton(
                  icon: AppIcons.checkSquareOffset,
                  tooltip: 'Toplu seçim',
                  onPressed: () => setState(() => _isSelectionMode = true),
                ),
              GhostIconButton(
                icon: _searching ? AppIcons.x : AppIcons.magnifyingGlass,
                tooltip: _searching ? 'Close search' : 'Search reminders',
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query = '';
                }),
              ),
            ],
          ),
        if (_searching && !_isSelectionMode) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            style: AppType.bodySmall.copyWith(color: c.text),
            cursorColor: c.accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search titles and notes',
              hintStyle: AppType.bodySmall.copyWith(color: c.inactive),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (all.isEmpty)
          EmptyState(
            icon: AppIcons.bellSimpleSlash,
            title: 'No reminders yet',
            message:
                'Use reminders to nudge the next action, so your habits and '
                'tasks stay on track.',
          )
        else if (groups.every((g) => g.reminders.isEmpty))
          EmptyState(
            icon: AppIcons.magnifyingGlass,
            title: 'Nothing matches',
            message: 'No reminder title or note contains "$_query".',
          )
        else
          for (final group in groups)
            if (group.reminders.isNotEmpty) ...[
              _Group(
                group: group,
                isSelectionMode: _isSelectionMode,
                selectedIds: _selectedIds,
                onToggleSelect: _toggleSelect,
                onStartSelection: _startSelection,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
      ],
    );
  }

  /// Overdue · Today · Upcoming, in that order.
  ///
  /// A completed reminder stays in whichever group its time puts it and sorts
  /// to the bottom of it — the same rule the rail uses. It does not move to a
  /// "Done" group, because then finishing something would make it vanish from
  /// where the user was looking.
  List<_ReminderGroup> _group(List<ReminderItem> all, DateTime now) {
    final query = _query.trim().toLowerCase();
    final matching = query.isEmpty
        ? all
        : all
              .where(
                (r) =>
                    r.title.toLowerCase().contains(query) ||
                    r.message.toLowerCase().contains(query),
              )
              .toList();

    final overdue = <ReminderItem>[];
    final today = <ReminderItem>[];
    final upcoming = <ReminderItem>[];

    for (final r in matching) {
      final due = r.dueAt;
      if (due == null) {
        upcoming.add(r);
      } else if (_isSameDay(due, now)) {
        today.add(r);
      } else if (due.isBefore(now)) {
        // Only a *completed* overdue reminder is uninteresting; an
        // incomplete one is the whole reason this group leads the screen.
        overdue.add(r);
      } else {
        upcoming.add(r);
      }
    }

    for (final list in [overdue, today, upcoming]) {
      list.sort(_compare);
    }

    return [
      _ReminderGroup('Overdue', overdue, overdue: true),
      _ReminderGroup('Today', today),
      _ReminderGroup('Upcoming', upcoming),
    ];
  }

  static int _compare(ReminderItem a, ReminderItem b) {
    final aDone = a.status == ReminderStatus.completed;
    final bDone = b.status == ReminderStatus.completed;
    if (aDone != bDone) return aDone ? 1 : -1;
    if (a.dueAt == null && b.dueAt == null) return a.title.compareTo(b.title);
    if (a.dueAt == null) return 1;
    if (b.dueAt == null) return -1;
    return a.dueAt!.compareTo(b.dueAt!);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ReminderGroup {
  const _ReminderGroup(this.label, this.reminders, {this.overdue = false});

  final String label;
  final List<ReminderItem> reminders;
  final bool overdue;
}

class _Group extends ConsumerWidget {
  const _Group({
    required this.group,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.onStartSelection,
  });

  final _ReminderGroup group;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<String>? onStartSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final open = group.reminders
        .where((r) => r.status != ReminderStatus.completed)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$open',
              style: AppType.numeral.copyWith(
                color: group.overdue ? c.accent : c.text,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Kicker(
                group.label,
                color: group.overdue ? c.inkAccent : c.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              // The one marked group gets a 2px accent edge; the others a
              // hairline. Same structure, different weight.
              left: BorderSide(
                color: group.overdue ? c.accent : c.divider,
                width: group.overdue ? 2 : 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Column(
              children: [
                for (var i = 0; i < group.reminders.length; i++)
                  ReminderCard(
                    key: ValueKey(group.reminders[i].id),
                    reminder: group.reminders[i],
                    overdue: group.overdue,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedIds.contains(group.reminders[i].id),
                    showDivider: i < group.reminders.length - 1,
                    onSelect: () => onToggleSelect?.call(group.reminders[i].id),
                    onLongPress: () {
                      if (!isSelectionMode) {
                        onStartSelection?.call(group.reminders[i].id);
                      }
                    },
                    onTap: () {
                      if (isSelectionMode) {
                        onToggleSelect?.call(group.reminders[i].id);
                      } else {
                        context.push(
                          '/reminders/${group.reminders[i].id}/edit',
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Formats a reminder's due time for a list row.
///
/// Time alone for today, weekday + time within the week, date + time beyond
/// it. The column is fixed-width and tabular either way.
///
/// **The time is always shown, and always as AM/PM.** The two outer branches
/// used to print a weekday or a date and stop there, which meant the one
/// thing a reminder actually is — a moment — was missing from every row that
/// wasn't today's. `DateFormat.jm()` is the 12-hour pattern for the locale;
/// the whole reminders surface is pinned to it, pickers included.
String reminderTimeLabel(DateTime? due, DateTime now) {
  if (due == null) return '';
  final time = DateFormat.jm().format(due);
  if (due.year == now.year && due.month == now.month && due.day == now.day) {
    return time;
  }
  final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days.abs() < 7) return '${DateFormat('EEE').format(due)} $time';
  return '${DateFormat('d MMM').format(due)} $time';
}
