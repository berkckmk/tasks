import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_icons.dart';
import '../constants/app_spacing.dart';

/// A configuration row matching the screenshot design:
/// Leading icon -> text/title -> optional clear button [-] -> tap handler.
class DetailRowItem extends StatelessWidget {
  const DetailRowItem({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.textColor,
    this.trailing,
    this.onClear,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final effectiveIconColor = iconColor ?? c.muted;
    final effectiveTextColor = textColor ?? c.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: c.accentTint(0.08),
            highlightColor: c.accentTint(0.04),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: effectiveIconColor),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: AppType.body.copyWith(
                        color: effectiveTextColor,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Temizle',
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: onClear,
                    )
                  else if (trailing != null)
                    trailing!
                  else
                    Icon(
                      AppIcons.caretRight,
                      size: 16,
                      color: c.inactive,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.7,
            color: c.divider.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

/// The bottom pill container:
/// "[ İptal et  |  Kaydet ]" capsule button bar.
class PillActionBar extends StatelessWidget {
  const PillActionBar({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.isSaving = false,
    this.cancelLabel = 'İptal et',
    this.saveLabel = 'Kaydet',
  });

  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool isSaving;
  final String cancelLabel;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E), // Dark rounded pill matching screenshot
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cancel Button
          InkWell(
            onTap: isSaving ? null : onCancel,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                cancelLabel,
                style: AppType.bodySmall.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Vertical Divider
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          // Save Button
          InkWell(
            onTap: isSaving ? null : onSave,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      saveLabel,
                      style: AppType.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A modern Date and Time Picker Modal Sheet with quick shortcut chips
/// and detailed date & time dials.
class DateTimePickerSheet extends StatefulWidget {
  const DateTimePickerSheet({
    super.key,
    this.initialDateTime,
  });

  final DateTime? initialDateTime;

  static Future<DateTime?> show(BuildContext context, {DateTime? initial}) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DateTimePickerSheet(initialDateTime: initial),
    );
  }

  @override
  State<DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<DateTimePickerSheet> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDateTime ?? now.add(const Duration(hours: 1));
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedTime = TimeOfDay(hour: initial.hour, minute: initial.minute);
  }

  DateTime get _combined => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  void _setQuickDate(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
  }

  void _setQuickTime(int hour, int minute) {
    setState(() => _selectedTime = TimeOfDay(hour: hour, minute: minute));
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final thisWeekend = today.add(Duration(days: (6 - today.weekday + 7) % 7));

    final isToday = _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
    final isTomorrow = _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day;

    String dateLabel;
    if (isToday) {
      dateLabel = 'Bugün';
    } else if (isTomorrow) {
      dateLabel = 'Yarın';
    } else {
      try {
        dateLabel = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(_selectedDate);
      } catch (_) {
        try {
          dateLabel = DateFormat('d MMMM yyyy, EEEE').format(_selectedDate);
        } catch (_) {
          dateLabel = '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}';
        }
      }
    }

    final timeLabel = DateFormat.jm().format(_combined);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: c.edgeLg),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.inactive.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tarih ve Saat Seçimi',
                style: AppType.h4.copyWith(color: c.text),
              ),
              IconButton(
                icon: const Icon(AppIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Current selected summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.divider),
            ),
            child: Row(
              children: [
                Icon(AppIcons.calendarBlank, size: 20, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$dateLabel, $timeLabel',
                    style: AppType.body.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quick Date Chips
          Text('Tarih', style: AppType.meta.copyWith(color: c.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Bugün'),
                selected: isToday,
                onSelected: (_) => _setQuickDate(today),
              ),
              ChoiceChip(
                label: const Text('Yarın'),
                selected: isTomorrow,
                onSelected: (_) => _setQuickDate(tomorrow),
              ),
              ChoiceChip(
                label: const Text('Hafta Sonu'),
                selected: _selectedDate.year == thisWeekend.year &&
                    _selectedDate.month == thisWeekend.month &&
                    _selectedDate.day == thisWeekend.day,
                onSelected: (_) => _setQuickDate(thisWeekend),
              ),
              ActionChip(
                avatar: const Icon(AppIcons.calendarBlank, size: 16),
                label: const Text('Takvimden Seç...'),
                onPressed: _pickCustomDate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick Time Chips
          Text('Saat', style: AppType.meta.copyWith(color: c.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sabah (09:00)'),
                selected: _selectedTime.hour == 9 && _selectedTime.minute == 0,
                onSelected: (_) => _setQuickTime(9, 0),
              ),
              ChoiceChip(
                label: const Text('Öğle (13:00)'),
                selected: _selectedTime.hour == 13 && _selectedTime.minute == 0,
                onSelected: (_) => _setQuickTime(13, 0),
              ),
              ChoiceChip(
                label: const Text('Akşam (19:00)'),
                selected: _selectedTime.hour == 19 && _selectedTime.minute == 0,
                onSelected: (_) => _setQuickTime(19, 0),
              ),
              ChoiceChip(
                label: const Text('Gece (21:00)'),
                selected: _selectedTime.hour == 21 && _selectedTime.minute == 0,
                onSelected: (_) => _setQuickTime(21, 0),
              ),
              ActionChip(
                avatar: const Icon(AppIcons.clock, size: 16),
                label: const Text('Özel Saat...'),
                onPressed: _pickCustomTime,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, _combined),
            child: const Text(
              'Uygula',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic Option Picker Sheet for single-selection lists (Erken Uyarı, Tekrar, Ses, Kategori)
class OptionPickerSheet<T> extends StatelessWidget {
  const OptionPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.labelOf,
    this.iconOf,
    this.subtitleOf,
  });

  final String title;
  final List<T> items;
  final T selectedItem;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final String Function(T)? subtitleOf;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required T selectedItem,
    required String Function(T) labelOf,
    IconData Function(T)? iconOf,
    String Function(T)? subtitleOf,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => OptionPickerSheet<T>(
        title: title,
        items: items,
        selectedItem: selectedItem,
        labelOf: labelOf,
        iconOf: iconOf,
        subtitleOf: subtitleOf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: c.edgeLg),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.inactive.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title, style: AppType.h4.copyWith(color: c.text)),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: c.divider),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selectedItem;
                final label = labelOf(item);
                final subtitle = subtitleOf?.call(item);
                final icon = iconOf?.call(item);

                return ListTile(
                  leading: icon != null
                      ? Icon(
                          icon,
                          color: isSelected ? c.accent : c.muted,
                          size: 20,
                        )
                      : null,
                  title: Text(
                    label,
                    style: AppType.body.copyWith(
                      color: isSelected ? c.accent : c.text,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: subtitle != null
                      ? Text(
                          subtitle,
                          style: AppType.caption.copyWith(color: c.inactive),
                        )
                      : null,
                  trailing: isSelected
                      ? Icon(AppIcons.checkCircle, color: c.accent, size: 20)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt dialog for Location / Yer input
Future<String?> showLocationInputDialog(
  BuildContext context, {
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  final quickPlaces = ['Ev', 'İş / Ofis', 'Market', 'Eczane', 'Spor Salonu'];

  return showDialog<String>(
    context: context,
    builder: (context) {
      final c = AppColorsScheme.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        title: Text('Yer / Konum Belirle', style: AppType.h4.copyWith(color: c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: AppType.body.copyWith(color: c.text),
              decoration: InputDecoration(
                hintText: 'Örn: Ev, Ofis veya adres...',
                hintStyle: AppType.body.copyWith(color: c.inactive),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: quickPlaces.map((place) {
                return ActionChip(
                  label: Text(place),
                  onPressed: () {
                    controller.text = place;
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tamam'),
          ),
        ],
      );
    },
  );
}
