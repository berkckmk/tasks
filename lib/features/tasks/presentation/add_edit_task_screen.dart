import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/edit_target.dart';
import '../../../core/widgets/item_detail_sheet_components.dart';
import '../../../core/widgets/sheet_page.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../application/task_providers.dart';
import '../domain/task_item.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  const AddEditTaskScreen({super.key, this.taskId, this.initialTitle});

  final String? taskId;
  final String? initialTitle;

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newChecklistItemController = TextEditingController();

  DateTime? _startDate;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TaskPriority _priority = TaskPriority.medium;
  String? _relatedGoalId;
  String _repeatRule = 'Tekrarlama';
  int? _earlyAlertMinutes;
  bool _syncEnabled = false;
  final List<String> _checklist = [];

  bool _showNotes = false;
  bool _showChecklist = false;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _titleController.text = widget.initialTitle!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _newChecklistItemController.dispose();
    super.dispose();
  }

  void _initFromExisting(TaskItem? task) {
    if (_initialized || task == null) return;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _startDate = task.effectiveStart;
    _dueDate = task.dueDate;
    _dueTime = task.allDay || task.dueDate == null
        ? null
        : TimeOfDay.fromDateTime(task.dueDate!);
    _priority = task.priority;
    _relatedGoalId = task.relatedGoalId;
    _syncEnabled = task.syncEnabled;
    _showNotes = task.description.isNotEmpty;
    _initialized = true;
  }

  String _formatWhen() {
    if (_dueDate == null) return 'Tarih ve saat belirle';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    final timePart = _dueTime != null
        ? ', ${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'
        : ' (Tüm gün)';

    if (thatDay == today) {
      return 'Bugün$timePart';
    } else if (thatDay == today.add(const Duration(days: 1))) {
      return 'Yarın$timePart';
    } else {
      try {
        return '${DateFormat('d MMMM', 'tr_TR').format(_dueDate!)}$timePart';
      } catch (_) {
        return '${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}$timePart';
      }
    }
  }

  String _formatEarlyAlert(int? minutes) {
    if (minutes == null || minutes == 0) return 'Erken uyarı yok';
    if (minutes < 60) return '$minutes dakika önce';
    if (minutes == 60) return '1 saat önce';
    if (minutes == 1440) return '1 gün önce';
    return '${minutes ~/ 60} saat önce';
  }

  Future<void> _pickWhen() async {
    final initial = _dueDate != null
        ? DateTime(
            _dueDate!.year,
            _dueDate!.month,
            _dueDate!.day,
            _dueTime?.hour ?? 12,
            _dueTime?.minute ?? 0,
          )
        : DateTime.now().add(const Duration(hours: 1));

    final picked = await DateTimePickerSheet.show(context, initial: initial);
    if (picked != null && mounted) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day);
        _startDate ??= _dueDate;
        _dueTime = TimeOfDay(hour: picked.hour, minute: picked.minute);
      });
    }
  }

  Future<void> _pickEarlyAlert() async {
    const options = [0, 5, 10, 15, 30, 60, 1440];
    final picked = await OptionPickerSheet.show<int>(
      context,
      title: 'Erken Uyarı',
      items: options,
      selectedItem: _earlyAlertMinutes ?? 0,
      labelOf: (m) => _formatEarlyAlert(m),
      iconOf: (m) => AppIcons.bell,
    );
    if (picked != null && mounted) {
      setState(() => _earlyAlertMinutes = picked == 0 ? null : picked);
    }
  }

  Future<void> _pickRepeat() async {
    const options = [
      'Tekrarlama',
      'Her gün',
      'Hafta içi (Pzt-Cum)',
      'Her hafta',
      'Her ay',
      'Her yıl',
    ];
    final picked = await OptionPickerSheet.show<String>(
      context,
      title: 'Tekrarlama',
      items: options,
      selectedItem: _repeatRule,
      labelOf: (s) => s,
      iconOf: (_) => AppIcons.arrowsClockwise,
    );
    if (picked != null && mounted) {
      setState(() => _repeatRule = picked);
    }
  }

  Future<void> _pickPriority() async {
    final picked = await OptionPickerSheet.show<TaskPriority>(
      context,
      title: 'Öncelik Seviyesi',
      items: TaskPriority.values,
      selectedItem: _priority,
      labelOf: (p) => p.label,
      iconOf: (p) => AppIcons.flag,
    );
    if (picked != null && mounted) {
      setState(() => _priority = picked);
    }
  }

  Future<void> _pickGoal(List<Goal> goals) async {
    final picked = await OptionPickerSheet.show<Goal?>(
      context,
      title: 'Hedef Bağla',
      items: [null, ...goals],
      selectedItem:
          goals.where((g) => g.id == _relatedGoalId).firstOrNull,
      labelOf: (g) => g?.title ?? 'Hedef Yok',
      iconOf: (_) => AppIcons.target,
    );
    if (mounted) {
      setState(() => _relatedGoalId = picked?.id);
    }
  }

  void _addChecklistItem() {
    final text = _newChecklistItemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(text);
      _newChecklistItemController.clear();
    });
  }

  Future<void> _confirmDelete(BuildContext context, String taskId) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Görev silinsin mi?',
      message: 'Bu işlem geri alınamaz.',
    );
    if (!confirmed) return;

    try {
      await ref.read(taskActionsProvider).deleteTask(taskId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Silinemedi: $e")));
      }
    }
  }

  Future<void> _save(TaskItem? existing) async {
    final titleText = _titleController.text.trim();
    if (titleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir görev başlığı girin')),
      );
      return;
    }

    DateTime? effectiveDueDate;
    if (_dueDate != null) {
      if (_dueTime != null) {
        effectiveDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
      } else {
        effectiveDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
        );
      }
    }

    var desc = _descriptionController.text.trim();
    if (_checklist.isNotEmpty) {
      final checklistStr = _checklist.map((item) => '- [ ] $item').join('\n');
      desc = desc.isEmpty ? checklistStr : '$desc\n\n$checklistStr';
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(taskActionsProvider).saveTask(
            id: existing?.id,
            title: titleText,
            description: desc,
            startDate: _startDate ?? effectiveDueDate,
            dueDate: effectiveDueDate,
            allDay: _dueTime == null,
            priority: _priority,
            status: existing?.status ?? TaskStatus.todo,
            relatedGoalId: _relatedGoalId,
          );

      if (existing != null && _syncEnabled != existing.syncEnabled) {
        await ref
            .read(taskActionsProvider)
            .setSyncEnabled(existing.id, _syncEnabled);
      }

      if (mounted) context.pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Görev kaydedilemedi.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Görev kaydedilemedi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final isEditing = widget.taskId != null;
    final screenTitle = isEditing ? 'Görevi düzenle' : 'Yeni görev';
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Goal>[];

    final target = EditTarget.resolve<TaskItem>(
      id: widget.taskId,
      async: ref.watch(tasksProvider),
      idOf: (task) => task.id,
    );

    TaskItem? existing;
    switch (target) {
      case EditTargetLoading():
        return EditTargetLoadingScreen(title: screenTitle);
      case EditTargetFailed(:final error):
        return EditTargetMissingScreen(
          title: screenTitle,
          message: '',
          error: error,
        );
      case EditTargetMissing():
        return EditTargetMissingScreen(
          title: screenTitle,
          message: 'Bu görev artık mevcut değil.',
        );
      case EditTargetFound(:final item):
        existing = item;
        _initFromExisting(existing);
      case EditTargetCreating():
        existing = null;
    }

    final goalTitle = _relatedGoalId == null
        ? null
        : goals
            .where((g) => g.id == _relatedGoalId)
            .map((g) => g.title)
            .firstOrNull;

    final isStarred = _priority == TaskPriority.high;

    return SheetPanel(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar: Title + Star toggle + Delete
                Row(
                  children: [
                    Text(
                      screenTitle,
                      style: AppType.h3.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (existing != null)
                      IconButton(
                        icon: const Icon(AppIcons.trash, size: 20),
                        tooltip: 'Sil',
                        onPressed: () => _confirmDelete(context, existing!.id),
                      ),
                    IconButton(
                      icon: Icon(
                        isStarred ? Icons.star : Icons.star_border,
                        color: isStarred ? const Color(0xFFFFB300) : c.muted,
                        size: 24,
                      ),
                      tooltip: isStarred
                          ? 'Önemliyi kaldır (Normal öncelik yap)'
                          : 'Yüksek öncelik olarak işaretle',
                      onPressed: () {
                        setState(() {
                          _priority = isStarred
                              ? TaskPriority.medium
                              : TaskPriority.high;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Başlık (Title)
                TextField(
                  controller: _titleController,
                  autofocus: !isEditing,
                  style: AppType.h4.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: 'Başlık',
                    hintStyle: AppType.h4.copyWith(
                      color: c.inactive,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Quick Action Icons (Checklist toggle & Notes toggle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        _showChecklist
                            ? AppIcons.checkSquareOffset
                            : AppIcons.checkSquare,
                        size: 22,
                        color: _showChecklist ? c.accent : c.muted,
                      ),
                      tooltip: 'Alt maddeler / Checklist',
                      onPressed: () =>
                          setState(() => _showChecklist = !_showChecklist),
                    ),
                    IconButton(
                      icon: Icon(
                        _showNotes ? AppIcons.note : AppIcons.camera,
                        size: 22,
                        color: _showNotes ? c.accent : c.muted,
                      ),
                      tooltip: 'Not / Açıklama ekle',
                      onPressed: () => setState(() => _showNotes = !_showNotes),
                    ),
                  ],
                ),

                // Conditional: Notes
                if (_showNotes) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.bg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.divider),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      minLines: 2,
                      style: AppType.bodySmall.copyWith(color: c.text),
                      cursorColor: c.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        hintText: 'Açıklama veya not ekleyin...',
                        hintStyle:
                            AppType.bodySmall.copyWith(color: c.inactive),
                      ),
                    ),
                  ),
                ],

                // Conditional: Checklist / Subtasks
                if (_showChecklist) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.bg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alt Görevler',
                            style: AppType.meta.copyWith(color: c.muted)),
                        const SizedBox(height: 6),
                        for (int i = 0; i < _checklist.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_box_outline_blank,
                                    size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_checklist[i],
                                      style: AppType.bodySmall
                                          .copyWith(color: c.text)),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _checklist.removeAt(i)),
                                  child: Icon(AppIcons.x,
                                      size: 16, color: c.inactive),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newChecklistItemController,
                                style:
                                    AppType.bodySmall.copyWith(color: c.text),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '+ Yeni alt görev...',
                                  hintStyle: AppType.bodySmall
                                      .copyWith(color: c.inactive),
                                ),
                                onSubmitted: (_) => _addChecklistItem(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(AppIcons.plus, size: 18),
                              onPressed: _addChecklistItem,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 0.7,
                  color: c.divider.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 8),

                // Row 1: Tarih ve Saat (Bugün, 19:00 + clear)
                DetailRowItem(
                  icon: AppIcons.calendarBlank,
                  title: _formatWhen(),
                  iconColor: c.text,
                  textColor: _dueDate != null ? c.text : c.inactive,
                  onClear: _dueDate != null
                      ? () => setState(() {
                            _dueDate = null;
                            _startDate = null;
                            _dueTime = null;
                          })
                      : null,
                  onTap: _pickWhen,
                ),

                // Row 2: Erken Uyarı (Erken uyarı yok)
                DetailRowItem(
                  icon: AppIcons.bell,
                  title: _formatEarlyAlert(_earlyAlertMinutes),
                  iconColor: c.text,
                  onTap: _pickEarlyAlert,
                ),

                // Row 3: Tekrarlama (Tekrarlama)
                DetailRowItem(
                  icon: AppIcons.arrowsClockwise,
                  title: _repeatRule,
                  iconColor: c.text,
                  onTap: _pickRepeat,
                ),

                // Row 4: Hedef / Proje Bağlantısı
                DetailRowItem(
                  icon: AppIcons.target,
                  title: goalTitle ?? 'Hedef veya Proje',
                  iconColor: c.text,
                  textColor: goalTitle != null ? c.text : c.inactive,
                  onClear: _relatedGoalId != null
                      ? () => setState(() => _relatedGoalId = null)
                      : null,
                  onTap: goals.isEmpty ? null : () => _pickGoal(goals),
                ),

                // Row 5: Öncelik Seviyesi (Yüksek / Orta / Düşük)
                DetailRowItem(
                  icon: AppIcons.flag,
                  title: _priority.label,
                  iconColor: _priority.color,
                  onTap: _pickPriority,
                ),

                // Row 6: Google Takvim Eşitleme
                DetailRowItem(
                  icon: AppIcons.googleLogo,
                  title: _syncEnabled
                      ? 'Google Takvim ile eşitleniyor'
                      : 'Google Takvim senkronizasyonu',
                  iconColor: const Color(0xFF4285F4),
                  trailing: Switch.adaptive(
                    value: _syncEnabled,
                    onChanged: (val) => setState(() => _syncEnabled = val),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),

          // Bottom Capsule Action Bar: [ İptal et  |  Kaydet ]
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: PillActionBar(
                onCancel: () => context.pop(),
                onSave: () => _save(existing),
                isSaving: _isSaving,
                cancelLabel: 'İptal et',
                saveLabel: 'Kaydet',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
