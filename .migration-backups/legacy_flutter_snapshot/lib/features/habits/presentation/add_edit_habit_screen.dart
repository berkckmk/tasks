import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/edit_target.dart';
import '../../../core/widgets/item_detail_sheet_components.dart';
import '../../../core/widgets/sheet_page.dart';
import '../../google_integrations/application/google_integrations_providers.dart';
import '../../google_integrations/domain/google_sync_status.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  const AddEditHabitScreen({super.key, this.habitId});

  final String? habitId;

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  final _nameController = TextEditingController();
  HabitCategory _category = HabitCategory.morning;
  String _frequencyLabel = 'Daily';
  String? _reminderTimeLabel;
  Color _color = AppColors.deepGreen;
  bool _initialized = false;
  bool _isSaving = false;

  static const _frequencyOptions = [
    'Daily',
    '3x / week',
    '5x / week',
    'Weekdays',
    'Weekly',
  ];
  static const _colorOptions = [
    AppColors.deepGreen,
    AppColors.mutedBlue,
    AppColors.amber,
    Color(0xFF8E6C88),
    Color(0xFF3E6E7E),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initFromExisting(Habit? habit) {
    if (_initialized || habit == null) return;
    _nameController.text = habit.name;
    _category = habit.category;
    _frequencyLabel = habit.frequencyLabel;
    _reminderTimeLabel = habit.reminderTimeLabel;
    _color = habit.color;
    _initialized = true;
  }

  String _formatCategory(HabitCategory c) => c.label;

  Future<void> _pickCategory() async {
    final picked = await OptionPickerSheet.show<HabitCategory>(
      context,
      title: 'Kategori',
      items: HabitCategory.values,
      selectedItem: _category,
      labelOf: (c) => c.label,
      iconOf: (_) => AppIcons.tag,
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  Future<void> _pickFrequency() async {
    final picked = await OptionPickerSheet.show<String>(
      context,
      title: 'Sıklık',
      items: _frequencyOptions,
      selectedItem: _frequencyLabel,
      labelOf: (s) => s,
      iconOf: (_) => AppIcons.arrowsClockwise,
    );
    if (picked != null && mounted) {
      setState(() => _frequencyLabel = picked);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _reminderTimeLabel = picked.format(context));
    }
  }

  Future<void> _pickColor() async {
    final picked = await OptionPickerSheet.show<Color>(
      context,
      title: 'Renk',
      items: _colorOptions,
      selectedItem: _color,
      labelOf: (c) {
        if (c == AppColors.deepGreen) return 'Yeşil';
        if (c == AppColors.mutedBlue) return 'Mavi';
        if (c == AppColors.amber) return 'Sarı';
        if (c == const Color(0xFF8E6C88)) return 'Mor';
        if (c == const Color(0xFF3E6E7E)) return 'Deniz';
        return 'Renk';
      },
      iconOf: (_) => AppIcons.sparkle,
    );
    if (picked != null && mounted) {
      setState(() => _color = picked);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String habitId) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Alışkanlık silinsin mi?',
      message:
          'Tamamlanma geçmişi de silinecektir. Bu işlem geri alınamaz.',
    );
    if (!confirmed) return;

    try {
      await ref.read(habitActionsProvider).deleteHabit(habitId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Silinemedi: $e")));
      }
    }
  }

  Future<void> _save(Habit? existing) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir alışkanlık adı girin')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(habitActionsProvider).saveHabit(
            id: existing?.id,
            name: name,
            category: _category,
            frequencyLabel: _frequencyLabel,
            colorValue: _color.toARGB32(),
            reminderTimeLabel: _reminderTimeLabel,
          );
      if (mounted) context.pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Alışkanlık kaydedilemedi.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Alışkanlık kaydedilemedi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final isEditing = widget.habitId != null;
    final screenTitle = isEditing ? 'Alışkanlığı düzenle' : 'Yeni alışkanlık';

    final target = EditTarget.resolve<Habit>(
      id: widget.habitId,
      async: ref.watch(habitsProvider),
      idOf: (habit) => habit.id,
    );

    final Habit? existing;
    switch (target) {
      case EditTargetLoading():
        return EditTargetLoadingScreen(title: screenTitle);
      case EditTargetFailed(:final error):
        return EditTargetMissingScreen(title: screenTitle, message: '', error: error);
      case EditTargetMissing():
        return EditTargetMissingScreen(
          title: screenTitle,
          message: 'Bu alışkanlık artık mevcut değil.',
        );
      case EditTargetFound(:final item):
        existing = item;
        _initFromExisting(existing);
      case EditTargetCreating():
        existing = null;
    }

    final calendarConnected =
        ref.watch(googleCalendarStatusProvider).valueOrNull?.status ==
        GoogleSyncStatus.connected;

    // Color name for display
    String colorName;
    if (_color == AppColors.deepGreen) {
      colorName = 'Yeşil';
    } else if (_color == AppColors.mutedBlue) {
      colorName = 'Mavi';
    } else if (_color == AppColors.amber) {
      colorName = 'Sarı';
    } else if (_color == const Color(0xFF8E6C88)) {
      colorName = 'Mor';
    } else if (_color == const Color(0xFF3E6E7E)) {
      colorName = 'Deniz';
    } else {
      colorName = 'Özel';
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
                // Top Bar: Title + Delete + Star-like indicator
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
                  ],
                ),
                const SizedBox(height: 12),

                // Name field
                TextField(
                  controller: _nameController,
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
                    hintText: 'Alışkanlık adı',
                    hintStyle: AppType.h4.copyWith(
                      color: c.inactive,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 0.7,
                  color: c.divider.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 8),

                // Row 1: Kategori
                DetailRowItem(
                  icon: AppIcons.tag,
                  title: _formatCategory(_category),
                  iconColor: c.text,
                  onTap: _pickCategory,
                ),

                // Row 2: Sıklık
                DetailRowItem(
                  icon: AppIcons.arrowsClockwise,
                  title: _frequencyLabel,
                  iconColor: c.text,
                  onTap: _pickFrequency,
                ),

                // Row 3: Hatırlatma Saati
                DetailRowItem(
                  icon: AppIcons.alarm,
                  title: _reminderTimeLabel ?? 'Hatırlatma saati',
                  iconColor: c.text,
                  textColor: _reminderTimeLabel != null ? c.text : c.inactive,
                  onClear: _reminderTimeLabel != null
                      ? () => setState(() => _reminderTimeLabel = null)
                      : null,
                  onTap: _pickReminderTime,
                ),

                // Row 4: Renk
                DetailRowItem(
                  icon: AppIcons.sparkle,
                  title: colorName,
                  iconColor: _color,
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color,
                      border: Border.all(color: c.divider),
                    ),
                  ),
                  onTap: _pickColor,
                ),

                // Row 5: Google Takvim (only in edit mode + connected)
                if (isEditing && existing != null && calendarConnected)
                  DetailRowItem(
                    icon: AppIcons.googleLogo,
                    title: existing.syncEnabled
                        ? 'Google Takvim ile eşitleniyor'
                        : 'Google Takvim senkronizasyonu',
                    iconColor: const Color(0xFF4285F4),
                    trailing: Switch.adaptive(
                      value: existing.syncEnabled,
                      onChanged: (value) => ref
                          .read(habitActionsProvider)
                          .setSyncEnabled(existing!.id, value),
                    ),
                    showDivider: false,
                  ),
              ],
            ),
          ),

          // Bottom Capsule Action Bar: [ İptal et | Kaydet ]
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
