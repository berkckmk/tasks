import { useState, type ReactNode } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { AppIcon } from './app-icon';
import { AppText, Kicker } from './app-text';
import { AppButton } from './app-button';
import { AppSheet } from './app-sheet';
import { AppTextField } from './app-text-field';
import { colors, radius, spacing, type AppIconName } from '@/theme';

// ---------------------------------------------------------------------------
// DetailRowItem — matches Flutter's DetailRowItem in
// item_detail_sheet_components.dart.
// Leading icon → text/title → optional clear button → caret.
// ---------------------------------------------------------------------------

type DetailRowProps = {
  icon: AppIconName;
  title: string;
  iconTone?: 'muted' | 'accent' | 'error' | 'text';
  textTone?: 'muted' | 'accent' | 'error' | 'text';
  trailing?: ReactNode;
  onClear?: () => void;
  onPress?: () => void;
  showDivider?: boolean;
};

export function DetailRow({
  icon,
  title,
  iconTone = 'muted',
  textTone = 'text',
  trailing,
  onClear,
  onPress,
  showDivider = true,
}: DetailRowProps) {
  return (
    <View>
      <Pressable
        onPress={onPress}
        style={({ pressed }) => [
          styles.detailRowContainer,
          pressed && styles.detailRowPressed,
        ]}
      >
        <AppIcon name={icon} size={20} tone={iconTone} />
        <AppText
          variant="body"
          tone={textTone}
          numberOfLines={1}
          style={styles.detailRowTitle}
        >
          {title}
        </AppText>
        {onClear ? (
          <Pressable onPress={onClear} hitSlop={8}>
            <AppIcon name="minusCircle" size={20} tone="error" />
          </Pressable>
        ) : trailing ? (
          trailing
        ) : (
          <AppIcon name="caretRight" size={16} tone="inactive" />
        )}
      </Pressable>
      {showDivider && <View style={styles.detailRowDivider} />}
    </View>
  );
}

// ---------------------------------------------------------------------------
// PillActionBar — the bottom "[ İptal et | Kaydet ]" capsule.
// ---------------------------------------------------------------------------

type PillActionBarProps = {
  onCancel: () => void;
  onSave: () => void;
  isSaving?: boolean;
  cancelLabel?: string;
  saveLabel?: string;
};

export function PillActionBar({
  onCancel,
  onSave,
  isSaving = false,
  cancelLabel = 'İptal et',
  saveLabel = 'Kaydet',
}: PillActionBarProps) {
  return (
    <View style={styles.pillBar}>
      <Pressable
        disabled={isSaving}
        onPress={onCancel}
        style={({ pressed }) => [
          styles.pillButton,
          styles.pillButtonLeft,
          pressed && styles.pillButtonPressed,
        ]}
      >
        <AppText variant="body" tone="muted" style={styles.pillButtonText}>
          {cancelLabel}
        </AppText>
      </Pressable>
      <View style={styles.pillDivider} />
      <Pressable
        disabled={isSaving}
        onPress={onSave}
        style={({ pressed }) => [
          styles.pillButton,
          styles.pillButtonRight,
          pressed && styles.pillButtonPressed,
        ]}
      >
        <AppText variant="body" tone="text" style={styles.pillSaveText}>
          {saveLabel}
        </AppText>
      </Pressable>
    </View>
  );
}

// ---------------------------------------------------------------------------
// DateTimePickerSheet — date/time picker with quick shortcut chips.
// ---------------------------------------------------------------------------

type DateTimePickerSheetProps = {
  presented: boolean;
  initialDateTime?: Date | null;
  onDismiss: () => void;
  onSelect: (date: Date) => void;
};

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function nextWeekend(from: Date) {
  const day = from.getDay();
  // Saturday = 6
  const daysUntil = (6 - day + 7) % 7;
  return new Date(from.getFullYear(), from.getMonth(), from.getDate() + (daysUntil || 7));
}

function formatTime(hours: number, minutes: number) {
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

export function DateTimePickerSheet({ presented, initialDateTime, onDismiss, onSelect }: DateTimePickerSheetProps) {
  const now = new Date();
  const fallback = new Date(now.getTime() + 60 * 60 * 1000);
  const initial = initialDateTime ?? fallback;

  const [selectedDate, setSelectedDate] = useState(() => new Date(initial.getFullYear(), initial.getMonth(), initial.getDate()));
  const [selectedHour, setSelectedHour] = useState(initial.getHours());
  const [selectedMinute, setSelectedMinute] = useState(initial.getMinutes());

  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
  const weekend = nextWeekend(today);

  const isToday = sameDay(selectedDate, today);
  const isTomorrow = sameDay(selectedDate, tomorrow);
  const isWeekend = sameDay(selectedDate, weekend);

  const dateLabel = isToday ? 'Bugün' : isTomorrow ? 'Yarın' : `${selectedDate.getDate()}.${selectedDate.getMonth() + 1}.${selectedDate.getFullYear()}`;

  function apply() {
    onSelect(new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate(), selectedHour, selectedMinute));
    onDismiss();
  }

  return (
    <AppSheet presented={presented} onDismiss={onDismiss}>
      <View style={styles.pickerHeader}>
        <AppText variant="h3">Tarih ve Saat Seçimi</AppText>
      </View>

      {/* Summary */}
      <View style={styles.pickerSummary}>
        <AppIcon name="calendarBlank" size={20} tone="accent" />
        <AppText variant="body" style={styles.pickerSummaryText}>
          {dateLabel}, {formatTime(selectedHour, selectedMinute)}
        </AppText>
      </View>

      {/* Date chips */}
      <Kicker>Tarih</Kicker>
      <View style={styles.chipRow}>
        <Chip label="Bugün" selected={isToday} onPress={() => setSelectedDate(today)} />
        <Chip label="Yarın" selected={isTomorrow} onPress={() => setSelectedDate(tomorrow)} />
        <Chip label="Hafta Sonu" selected={isWeekend} onPress={() => setSelectedDate(weekend)} />
      </View>

      {/* Time chips */}
      <Kicker>Saat</Kicker>
      <View style={styles.chipRow}>
        <Chip label="Sabah (09:00)" selected={selectedHour === 9 && selectedMinute === 0} onPress={() => { setSelectedHour(9); setSelectedMinute(0); }} />
        <Chip label="Öğle (13:00)" selected={selectedHour === 13 && selectedMinute === 0} onPress={() => { setSelectedHour(13); setSelectedMinute(0); }} />
        <Chip label="Akşam (19:00)" selected={selectedHour === 19 && selectedMinute === 0} onPress={() => { setSelectedHour(19); setSelectedMinute(0); }} />
        <Chip label="Gece (21:00)" selected={selectedHour === 21 && selectedMinute === 0} onPress={() => { setSelectedHour(21); setSelectedMinute(0); }} />
      </View>

      <AppButton label="Uygula" onPress={apply} />
    </AppSheet>
  );
}

// ---------------------------------------------------------------------------
// OptionPickerSheet — generic single-selection list for Erken Uyarı, Tekrar,
// Ses, Kategori, etc.
// ---------------------------------------------------------------------------

type OptionPickerItem<T> = {
  value: T;
  label: string;
  subtitle?: string;
  icon?: AppIconName;
};

type OptionPickerSheetProps<T> = {
  presented: boolean;
  title: string;
  items: OptionPickerItem<T>[];
  selectedValue: T;
  onSelect: (value: T) => void;
  onDismiss: () => void;
};

export function OptionPickerSheet<T>({
  presented,
  title,
  items,
  selectedValue,
  onSelect,
  onDismiss,
}: OptionPickerSheetProps<T>) {
  return (
    <AppSheet presented={presented} onDismiss={onDismiss}>
      <AppText variant="h3" style={{ marginBottom: spacing.md }}>{title}</AppText>
      <ScrollView>
        {items.map((item, index) => {
          const isSelected = item.value === selectedValue;
          return (
            <Pressable
              key={String(item.value)}
              onPress={() => { onSelect(item.value); onDismiss(); }}
              style={({ pressed }) => [
                styles.optionRow,
                pressed && styles.optionRowPressed,
              ]}
            >
              {item.icon && (
                <AppIcon
                  name={item.icon}
                  size={20}
                  tone={isSelected ? 'accent' : 'muted'}
                  style={{ marginRight: spacing.md }}
                />
              )}
              <View style={{ flex: 1 }}>
                <AppText
                  variant="body"
                  tone={isSelected ? 'accent' : 'text'}
                  style={isSelected ? styles.optionSelected : undefined}
                >
                  {item.label}
                </AppText>
                {item.subtitle && (
                  <AppText variant="caption" tone="inactive">{item.subtitle}</AppText>
                )}
              </View>
              {isSelected && (
                <AppIcon name="checkCircle" size={20} tone="accent" />
              )}
              {index < items.length - 1 && <View style={styles.optionDivider} />}
            </Pressable>
          );
        })}
      </ScrollView>
    </AppSheet>
  );
}

// ---------------------------------------------------------------------------
// LocationInputSheet — prompt for Yer/Konum with quick-place chips.
// ---------------------------------------------------------------------------

type LocationInputSheetProps = {
  presented: boolean;
  initialValue?: string;
  onDismiss: () => void;
  onSubmit: (value: string) => void;
};

const quickPlaces = ['Ev', 'İş / Ofis', 'Market', 'Eczane', 'Spor Salonu'];

export function LocationInputSheet({ presented, initialValue, onDismiss, onSubmit }: LocationInputSheetProps) {
  const [value, setValue] = useState(initialValue ?? '');
  return (
    <AppSheet presented={presented} onDismiss={onDismiss}>
      <AppText variant="h3" style={{ marginBottom: spacing.md }}>Yer / Konum Belirle</AppText>
      <AppTextField
        label="Konum"
        value={value}
        onChangeText={setValue}
        placeholder="Örn: Ev, Ofis veya adres..."
        autoFocus
      />
      <View style={styles.chipRow}>
        {quickPlaces.map((place) => (
          <Chip key={place} label={place} selected={value === place} onPress={() => setValue(place)} />
        ))}
      </View>
      <View style={styles.locationActions}>
        <AppButton label="İptal" variant="text" onPress={onDismiss} />
        <AppButton label="Tamam" onPress={() => { onSubmit(value.trim()); onDismiss(); }} />
      </View>
    </AppSheet>
  );
}

// ---------------------------------------------------------------------------
// Chip — internal small selectable tag.
// ---------------------------------------------------------------------------

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.chip, selected && styles.chipSelected]}
    >
      <AppText
        variant="caption"
        tone={selected ? 'accent' : 'muted'}
        style={selected ? styles.chipTextSelected : undefined}
      >
        {label}
      </AppText>
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  // DetailRow
  detailRowContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xs,
    borderRadius: radius.sm,
  },
  detailRowPressed: {
    opacity: 0.7,
  },
  detailRowTitle: {
    flex: 1,
    marginLeft: spacing.md,
  },
  detailRowDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.divider,
  },

  // PillActionBar
  pillBar: {
    flexDirection: 'row',
    alignSelf: 'center',
    height: 48,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    shadowColor: colors.background,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.45,
    shadowRadius: 14,
    elevation: 8,
    marginTop: spacing.lg,
  },
  pillButton: {
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  pillButtonLeft: {
    borderTopLeftRadius: radius.pill,
    borderBottomLeftRadius: radius.pill,
  },
  pillButtonRight: {
    borderTopRightRadius: radius.pill,
    borderBottomRightRadius: radius.pill,
  },
  pillButtonPressed: {
    opacity: 0.6,
  },
  pillButtonText: {
    fontWeight: '500',
  },
  pillSaveText: {
    fontWeight: '600',
  },
  pillDivider: {
    width: 1,
    height: 20,
    alignSelf: 'center',
    backgroundColor: colors.divider,
  },

  // DateTimePicker
  pickerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  pickerSummary: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    backgroundColor: colors.background,
    borderRadius: radius.md,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    marginBottom: spacing.md,
  },
  pickerSummaryText: {
    marginLeft: spacing.sm,
    fontWeight: '600',
  },

  // Chips
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: spacing.md,
  },
  chip: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.widgetPicker,
    borderWidth: 1,
    borderColor: colors.edgeSm,
    backgroundColor: colors.background,
  },
  chipSelected: {
    borderColor: colors.text,
    backgroundColor: colors.surfaceElevated,
  },
  chipTextSelected: {
    fontWeight: '600',
  },

  // OptionPicker
  optionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xs,
  },
  optionRowPressed: {
    opacity: 0.7,
  },
  optionSelected: {
    fontWeight: '600',
  },
  optionDivider: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.divider,
  },

  // Location
  locationActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.md,
    marginTop: spacing.md,
  },
});
