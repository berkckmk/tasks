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
import '../application/reminder_providers.dart';
import '../domain/reminder.dart';

class AddEditReminderScreen extends ConsumerStatefulWidget {
  const AddEditReminderScreen({
    super.key,
    this.reminderId,
    this.initialTitle,
  });

  final String? reminderId;
  final String? initialTitle;

  @override
  ConsumerState<AddEditReminderScreen> createState() =>
      _AddEditReminderScreenState();
}

class _AddEditReminderScreenState extends ConsumerState<AddEditReminderScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _newChecklistItemController = TextEditingController();

  DateTime? _dueAt;
  ReminderStatus _status = ReminderStatus.scheduled;
  ReminderPriority _priority = ReminderPriority.normal;
  bool _starred = false;
  int? _earlyAlertMinutes;
  String _repeatRule = 'Tekrarlama';
  String? _location;
  String _category = 'Hatırlatıcılarım';
  List<String> _checklist = [];

  bool _showNotes = false;
  bool _showChecklist = false;
  bool _userChangedPriority = false;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _titleController.text = widget.initialTitle!;
    }
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _messageController.dispose();
    _newChecklistItemController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (!_userChangedPriority) {
      final lower = _titleController.text.toLowerCase();
      final isMed = lower.contains('duxet') ||
          lower.contains('aubagio') ||
          lower.contains('folik') ||
          lower.contains('ilaç') ||
          lower.contains('ilac') ||
          lower.contains('hap');
      if (isMed && _priority != ReminderPriority.important) {
        setState(() {
          _priority = ReminderPriority.important;
          _starred = true;
        });
      }
    }
  }

  void _initFromExisting(ReminderItem? reminder) {
    if (_initialized || reminder == null) return;
    _titleController.text = reminder.title;
    _messageController.text = reminder.message;
    _dueAt = reminder.dueAt;
    _status = reminder.status;
    _priority = reminder.priority;
    _starred = reminder.starred || reminder.priority == ReminderPriority.important;
    _earlyAlertMinutes = reminder.earlyAlertMinutes;
    _repeatRule = reminder.repeatRule ?? 'Tekrarlama';
    _location = reminder.location;
    _category = reminder.category.isNotEmpty ? reminder.category : 'Hatırlatıcılarım';
    _checklist = List.from(reminder.checklist);
    _showNotes = reminder.message.isNotEmpty;
    _showChecklist = reminder.checklist.isNotEmpty;
    _userChangedPriority = true;
    _initialized = true;
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return 'Tarih ve saat belirle';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('HH:mm').format(dt);

    if (thatDay == today) {
      return 'Bugün, $timeStr';
    } else if (thatDay == today.add(const Duration(days: 1))) {
      return 'Yarın, $timeStr';
    } else {
      try {
        return '${DateFormat('d MMMM', 'tr_TR').format(dt)}, $timeStr';
      } catch (_) {
        return '${dt.day}.${dt.month}.${dt.year}, $timeStr';
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

  String _formatPriority(ReminderPriority p) {
    switch (p) {
      case ReminderPriority.important:
        return 'Güçlü';
      case ReminderPriority.normal:
        return 'Normal';
      case ReminderPriority.low:
        return 'Sessiz';
    }
  }

  Future<void> _pickWhen() async {
    final picked = await DateTimePickerSheet.show(
      context,
      initial: _dueAt ?? DateTime.now().add(const Duration(hours: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _dueAt = picked);
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

  Future<void> _pickLocation() async {
    final picked = await showLocationInputDialog(
      context,
      initialValue: _location,
    );
    if (picked != null && mounted) {
      setState(() => _location = picked.isEmpty ? null : picked);
    }
  }

  Future<void> _pickPriority() async {
    final picked = await OptionPickerSheet.show<ReminderPriority>(
      context,
      title: 'Ses & Uyarı Gücü',
      items: ReminderPriority.values,
      selectedItem: _priority,
      labelOf: (p) => _formatPriority(p),
      iconOf: (p) => p == ReminderPriority.important
          ? AppIcons.speakerHigh
          : (p == ReminderPriority.low
              ? AppIcons.bellSimpleSlash
              : AppIcons.bell),
      subtitleOf: (p) => p.description,
    );
    if (picked != null && mounted) {
      setState(() {
        _priority = picked;
        _userChangedPriority = true;
        if (_priority == ReminderPriority.important) {
          _starred = true;
        }
      });
    }
  }

  Future<void> _pickCategory() async {
    const categories = [
      'Hatırlatıcılarım',
      'İş',
      'Kişisel',
      'Sağlık & İlaç',
      'Alışveriş',
      'Hedefler',
    ];
    final picked = await OptionPickerSheet.show<String>(
      context,
      title: 'Kategori / Liste',
      items: categories,
      selectedItem: _category,
      labelOf: (c) => c,
      iconOf: (_) => AppIcons.tag,
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
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

  Future<void> _confirmDelete(BuildContext context, String reminderId) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hatırlatıcı silinsin mi?',
      message: 'Bu işlem geri alınamaz.',
    );
    if (!confirmed) return;

    try {
      await ref.read(reminderActionsProvider).deleteReminder(reminderId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Silinemedi: $e")));
      }
    }
  }

  Future<void> _save(ReminderItem? existing) async {
    final titleText = _titleController.text.trim();
    if (titleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir başlık girin')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(reminderActionsProvider).saveReminder(
            id: existing?.id,
            title: titleText,
            message: _messageController.text.trim(),
            dueAt: _dueAt,
            status: _status,
            priority: _priority,
            starred: _starred,
            earlyAlertMinutes: _earlyAlertMinutes,
            repeatRule: _repeatRule,
            location: _location,
            category: _category,
            checklist: _checklist,
          );
      if (mounted) context.pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Kaydedilemedi.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kaydedilemedi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final isEditing = widget.reminderId != null;
    final screenTitle = isEditing ? 'Hatırlatıcıyı düzenle' : 'Yeni hatırlatıcı';

    final target = EditTarget.resolve<ReminderItem>(
      id: widget.reminderId,
      async: ref.watch(remindersProvider),
      idOf: (r) => r.id,
    );

    ReminderItem? existing;
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
          message: 'Bu hatırlatıcı artık mevcut değil.',
        );
      case EditTargetFound(:final item):
        existing = item;
        _initFromExisting(existing);
      case EditTargetCreating():
        existing = null;
    }

    return SheetPanel(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar: Title + Star icon (matching screenshot)
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
                    // Star button: Önemli / Favori
                    IconButton(
                      icon: Icon(
                        _starred ? Icons.star : Icons.star_border,
                        color: _starred ? const Color(0xFFFFB300) : c.muted,
                        size: 24,
                      ),
                      tooltip: _starred ? 'Önemli işaretini kaldır' : 'Önemli işaretle',
                      onPressed: () {
                        setState(() {
                          _starred = !_starred;
                          if (_starred) {
                            _priority = ReminderPriority.important;
                          } else if (_priority == ReminderPriority.important) {
                            _priority = ReminderPriority.normal;
                          }
                          _userChangedPriority = true;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Başlık (Title field)
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

                // Quick Action Icons (Checklist toggle & Camera/Note toggle)
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
                      tooltip: 'Alt maddeler / Liste',
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

                // Conditional: Notes Field
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
                      controller: _messageController,
                      maxLines: null,
                      minLines: 2,
                      style: AppType.bodySmall.copyWith(color: c.text),
                      cursorColor: c.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        hintText: 'Açıklama veya not ekleyin...',
                        hintStyle: AppType.bodySmall.copyWith(color: c.inactive),
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
                        Text('Alt Maddeler', style: AppType.meta.copyWith(color: c.muted)),
                        const SizedBox(height: 6),
                        for (int i = 0; i < _checklist.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_box_outline_blank, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_checklist[i], style: AppType.bodySmall.copyWith(color: c.text)),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _checklist.removeAt(i)),
                                  child: Icon(AppIcons.x, size: 16, color: c.inactive),
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
                                style: AppType.bodySmall.copyWith(color: c.text),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '+ Yeni madde yazın...',
                                  hintStyle: AppType.bodySmall.copyWith(color: c.inactive),
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

                // Row 1: Tarih ve Saat (Bugün, 19:00 + minus clear button)
                DetailRowItem(
                  icon: AppIcons.calendarBlank,
                  title: _formatWhen(_dueAt),
                  iconColor: c.text,
                  textColor: _dueAt != null ? c.text : c.inactive,
                  onClear: _dueAt != null
                      ? () => setState(() => _dueAt = null)
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

                // Row 4: Yer (Yer)
                DetailRowItem(
                  icon: AppIcons.mapPin,
                  title: _location ?? 'Yer',
                  iconColor: c.text,
                  textColor: _location != null ? c.text : c.inactive,
                  onClear: _location != null
                      ? () => setState(() => _location = null)
                      : null,
                  onTap: _pickLocation,
                ),

                // Row 5: Ses & Uyarı Gücü (Güçlü)
                DetailRowItem(
                  icon: AppIcons.speakerHigh,
                  title: _formatPriority(_priority),
                  iconColor: c.text,
                  onTap: _pickPriority,
                ),

                // Row 6: Kategori / Liste (Hatırlatıcılarım)
                DetailRowItem(
                  icon: AppIcons.bell,
                  title: _category,
                  iconColor: const Color(0xFF8B5CF6), // Purple accent from screenshot
                  textColor: c.text,
                  onTap: _pickCategory,
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
