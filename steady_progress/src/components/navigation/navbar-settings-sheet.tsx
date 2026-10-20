import React, { useState } from 'react';
import {
  LayoutAnimation,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { AppBottomSheet } from '@/components/modal/app-bottom-sheet';
import { AppIcon } from '@/components/ui/app-icon';
import { AppText, Kicker } from '@/components/ui/app-text';
import { AppButton } from '@/components/ui/app-button';
import {
  ALL_NAV_ITEMS,
  DEFAULT_NAVBAR_SLOTS,
  FIXED_MORE_SLOT,
  SELECTABLE_TRACKING_ITEMS,
  type NavCategory,
  type NavItemConfig,
  type NavSlotId,
} from '@/features/navbar/navbar-items';
import { useNavBar } from '@/features/navbar/navbar-context';
import {
  colors,
  controlSize,
  getModuleDefaultActiveColor,
  getModuleDefaultColor,
  getNavBarSlotActiveColor,
  getNavBarSlotColor,
  getTabActiveColor,
  getTabColor,
  getTabGradient,
  hexToRgba,
  radius,
  spacing,
  typography,
} from '@/theme';

const CATEGORY_TABS: Array<{ id: 'all' | NavCategory; label: string }> = [
  { id: 'all', label: 'Tümü' },
  { id: 'plan', label: 'Planla' },
  { id: 'track', label: 'Takip et' },
  { id: 'evaluate', label: 'Değerlendir' },
  { id: 'core', label: 'Temel' },
];

export function NavBarSettingsSheet() {
  const {
    slots,
    isConfigModalOpen,
    closeConfigModal,
    updateSlots,
    replaceSlot,
    resetToDefaults,
  } = useNavBar();

  const [selectedSlotIndex, setSelectedSlotIndex] = useState<number | null>(0);
  const [activeCategory, setActiveCategory] = useState<'all' | NavCategory>('all');
  const [tempSlots, setTempSlots] = useState<[NavSlotId, NavSlotId, NavSlotId, NavSlotId]>(slots);

  // Sync tempSlots when modal opens or slots change
  React.useEffect(() => {
    if (isConfigModalOpen) {
      setTempSlots(slots);
      setSelectedSlotIndex(0);
    }
  }, [isConfigModalOpen, slots]);

  const filteredItems = SELECTABLE_TRACKING_ITEMS.filter((item) => {
    if (activeCategory === 'all') return true;
    return item.category === activeCategory;
  });

  const handleSelectSlotCard = (index: number) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setSelectedSlotIndex(index);
  };

  const handleRemoveSlot = (slotIdx: number) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    // Find next available item that is not in tempSlots
    const available = SELECTABLE_TRACKING_ITEMS.find((item) => !tempSlots.includes(item.id));
    if (!available) return;

    const next: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [...tempSlots];
    next[slotIdx] = available.id;
    setTempSlots(next);
  };

  const handleItemPress = (item: NavItemConfig) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    const existingIndex = tempSlots.indexOf(item.id);

    // If item is already placed, swap or highlight it
    if (existingIndex !== -1) {
      if (selectedSlotIndex !== null && selectedSlotIndex !== existingIndex) {
        // Swap slots
        const next: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [...tempSlots];
        next[existingIndex] = next[selectedSlotIndex];
        next[selectedSlotIndex] = item.id;
        setTempSlots(next);
      } else {
        setSelectedSlotIndex(existingIndex);
      }
      return;
    }

    // Assign to selected slot, or default to slot 0
    const targetIndex = selectedSlotIndex ?? 0;
    const next: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [...tempSlots];
    next[targetIndex] = item.id;
    setTempSlots(next);

    // Auto advance selection to next slot
    setSelectedSlotIndex((targetIndex + 1) % 4);
  };

  const handleSave = async () => {
    await updateSlots(tempSlots);
    closeConfigModal();
  };

  const handleReset = async () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setTempSlots([...DEFAULT_NAVBAR_SLOTS]);
    await resetToDefaults();
  };

  return (
    <AppBottomSheet presented={isConfigModalOpen} onDismiss={closeConfigModal}>
      <View style={styles.sheetHeader}>
        <View style={styles.titleRow}>
          <View style={styles.iconCircle}>
            <AppIcon name="slidersHorizontal" size={20} tone="accent" />
          </View>
          <View style={{ flex: 1 }}>
            <AppText variant="h3">Alt Gezinme Ayarları</AppText>
            <AppText tone="muted" variant="caption">
              Alt bardaki 4 takip alanını özelleştir. More butonu sabittir.
            </AppText>
          </View>
        </View>
      </View>

      {/* 4 VARIABLE SLOTS + 1 FIXED MORE SLOT PREVIEW */}
      <View style={styles.section}>
        <View style={styles.sectionHeaderRow}>
          <Kicker>ALT BAR DÜZENİ (4 DEĞİŞKEN + MORE)</Kicker>
          <AppText tone="caption" style={{ ...typography.metaSmall }}>
            {selectedSlotIndex !== null ? `Slot ${selectedSlotIndex + 1} seçili` : 'Değiştirmek için bir slota tıkla'}
          </AppText>
        </View>

        <View style={styles.slotsRow}>
          {tempSlots.map((slotId, index) => {
            const item = ALL_NAV_ITEMS[slotId];
            const isSelected = selectedSlotIndex === index;
            const tabColor = getNavBarSlotColor(index);
            const activeColor = getNavBarSlotActiveColor(index);

            return (
              <TouchableOpacity
                key={`slot-${index}`}
                activeOpacity={0.8}
                onPress={() => handleSelectSlotCard(index)}
                style={[
                  styles.slotCard,
                  isSelected && styles.slotCardSelected,
                  { borderColor: isSelected ? activeColor : colors.border },
                ]}
              >
                <View style={styles.slotBadge}>
                  <Text style={[styles.slotBadgeText, { color: isSelected ? activeColor : colors.muted }]}>
                    {index + 1}
                  </Text>
                </View>

                <View
                  style={[
                    styles.slotIconBox,
                    { backgroundColor: hexToRgba(tabColor, 0.22) },
                  ]}
                >
                  <AppIcon name={item.icon} filled color={activeColor} size={18} />
                </View>

                <Text style={styles.slotLabel} numberOfLines={1}>
                  {item.label}
                </Text>

                {/* Remove / swap button */}
                <TouchableOpacity
                  hitSlop={8}
                  onPress={(e) => {
                    e.stopPropagation();
                    handleRemoveSlot(index);
                  }}
                  style={styles.removeButton}
                  accessibilityLabel={`${item.label} kaldır`}
                >
                  <AppIcon name="arrowsClockwise" size={12} color={colors.muted} />
                </TouchableOpacity>
              </TouchableOpacity>
            );
          })}

          {/* FIXED 5TH MORE SLOT */}
          <View style={[styles.slotCard, styles.moreSlotCard]}>
            <View style={styles.moreLockBadge}>
              <AppIcon name="lockSimple" size={10} color={colors.navInactive} />
            </View>

            <View style={[styles.slotIconBox, { backgroundColor: hexToRgba(getNavBarSlotColor(4), 0.15) }]}>
              <AppIcon name="dotsThreeCircle" filled color={getNavBarSlotActiveColor(4)} size={18} />
            </View>

            <Text style={[styles.slotLabel, { color: colors.navInactive }]} numberOfLines={1}>
              More
            </Text>

            <View style={styles.fixedPill}>
              <Text style={styles.fixedPillText}>Sabit</Text>
            </View>
          </View>
        </View>
      </View>

      {/* CATEGORY FILTER TABS */}
      <View style={styles.section}>
        <View style={styles.sectionHeaderRow}>
          <Kicker>MORE SAYFASINDAN TAKİP ALANI SEÇ</Kicker>
          <AppText tone="muted" variant="caption">
            {selectedSlotIndex !== null ? `Slot ${selectedSlotIndex + 1}'e eklenecek` : ''}
          </AppText>
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.categoryScroll}
        >
          {CATEGORY_TABS.map((cat) => {
            const isActive = activeCategory === cat.id;
            return (
              <Pressable
                key={cat.id}
                onPress={() => setActiveCategory(cat.id)}
                style={[
                  styles.categoryPill,
                  isActive && styles.categoryPillActive,
                ]}
              >
                <Text
                  style={[
                    styles.categoryPillText,
                    isActive && styles.categoryPillTextActive,
                  ]}
                >
                  {cat.label}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* ITEMS LIST */}
        <View style={styles.itemsList}>
          {filteredItems.map((item) => {
            const placedIndex = tempSlots.indexOf(item.id);
            const isPlaced = placedIndex !== -1;
            const tabColor = isPlaced ? getNavBarSlotColor(placedIndex) : getModuleDefaultColor(item.id);
            const activeColor = isPlaced ? getNavBarSlotActiveColor(placedIndex) : getModuleDefaultActiveColor(item.id);

            return (
              <TouchableOpacity
                key={item.id}
                activeOpacity={0.7}
                onPress={() => handleItemPress(item)}
                style={[
                  styles.itemRow,
                  isPlaced && styles.itemRowPlaced,
                ]}
              >
                <View
                  style={[
                    styles.itemIconContainer,
                    { backgroundColor: hexToRgba(tabColor, 0.20) },
                  ]}
                >
                  <AppIcon name={item.icon} filled color={activeColor} size={20} />
                </View>

                <View style={{ flex: 1, gap: 2 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
                    <Text style={styles.itemTitle}>{item.title}</Text>
                    <View style={styles.itemCategoryTag}>
                      <Text style={styles.itemCategoryTagText}>{item.categoryLabel}</Text>
                    </View>
                  </View>
                  <Text style={styles.itemDesc} numberOfLines={1}>
                    {item.description}
                  </Text>
                </View>

                {isPlaced ? (
                  <View style={[styles.statusBadge, { backgroundColor: hexToRgba(tabColor, 0.25) }]}>
                    <AppIcon name="check" size={12} color={activeColor} />
                    <Text style={[styles.statusBadgeText, { color: activeColor }]}>
                      Slot {placedIndex + 1}
                    </Text>
                  </View>
                ) : (
                  <View style={styles.addButton}>
                    <AppIcon name="plus" size={14} tone="accent" />
                    <Text style={styles.addButtonText}>Ekle</Text>
                  </View>
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      {/* FOOTER ACTIONS */}
      <View style={styles.footer}>
        <AppButton
          label="Varsayılana Sıfırla"
          variant="secondary"
          onPress={() => void handleReset()}
          style={{ flex: 1 }}
        />
        <AppButton
          label="Kaydet ve Uygula"
          onPress={() => void handleSave()}
          style={{ flex: 1 }}
        />
      </View>
    </AppBottomSheet>
  );
}

const styles = StyleSheet.create({
  sheetHeader: {
    paddingBottom: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.divider,
    marginBottom: spacing.md,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  iconCircle: {
    width: 40,
    height: 40,
    borderRadius: radius.card,
    backgroundColor: colors.section,
    alignItems: 'center',
    justifyContent: 'center',
  },
  section: {
    gap: spacing.xs,
    marginBottom: spacing.md,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
  slotsRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    alignItems: 'stretch',
  },
  slotCard: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    borderWidth: 1.5,
    borderColor: colors.border,
    paddingVertical: spacing.sm,
    paddingHorizontal: 4,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    minHeight: 88,
    position: 'relative',
  },
  slotCardSelected: {
    backgroundColor: colors.section,
    elevation: 2,
    shadowColor: colors.text,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 6,
  },
  moreSlotCard: {
    borderColor: colors.divider,
    backgroundColor: colors.section,
    opacity: 0.85,
  },
  slotBadge: {
    position: 'absolute',
    top: 4,
    left: 6,
  },
  slotBadgeText: {
    ...typography.metaSmall,
    fontWeight: '700',
  },
  moreLockBadge: {
    position: 'absolute',
    top: 4,
    left: 6,
  },
  slotIconBox: {
    width: 32,
    height: 32,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  slotLabel: {
    ...typography.tabLabel,
    color: colors.text,
    fontWeight: '600',
    textAlign: 'center',
  },
  removeButton: {
    position: 'absolute',
    top: 4,
    right: 4,
    width: 20,
    height: 20,
    borderRadius: radius.pill,
    backgroundColor: colors.surfaceElevated,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fixedPill: {
    position: 'absolute',
    bottom: 4,
    paddingHorizontal: 4,
    paddingVertical: 1,
    borderRadius: radius.pill,
    backgroundColor: colors.divider,
  },
  fixedPillText: {
    ...typography.kickerSmall,
    color: colors.muted,
  },
  categoryScroll: {
    gap: spacing.xs,
    paddingVertical: 2,
    marginBottom: spacing.xs,
  },
  categoryPill: {
    paddingHorizontal: spacing.sm + 4,
    paddingVertical: 6,
    borderRadius: radius.pill,
    backgroundColor: colors.section,
  },
  categoryPillActive: {
    backgroundColor: colors.text,
  },
  categoryPillText: {
    ...typography.meta,
    color: colors.muted,
    fontWeight: '500',
  },
  categoryPillTextActive: {
    color: colors.surface,
    fontWeight: '600',
  },
  itemsList: {
    gap: spacing.xs,
  },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: spacing.sm + 2,
    paddingVertical: spacing.sm,
  },
  itemRowPlaced: {
    borderColor: colors.divider,
    backgroundColor: colors.surfaceElevated,
  },
  itemIconContainer: {
    width: 40,
    height: 40,
    borderRadius: radius.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
  itemTitle: {
    ...typography.title,
    color: colors.text,
  },
  itemDesc: {
    ...typography.note,
    color: colors.muted,
  },
  itemCategoryTag: {
    backgroundColor: colors.section,
    paddingHorizontal: 6,
    paddingVertical: 1,
    borderRadius: radius.sm,
  },
  itemCategoryTagText: {
    ...typography.kickerSmall,
    color: colors.muted,
  },
  statusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: radius.pill,
  },
  statusBadgeText: {
    ...typography.metaSmall,
    fontWeight: '600',
  },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: radius.pill,
    backgroundColor: colors.section,
    borderWidth: 1,
    borderColor: colors.border,
  },
  addButtonText: {
    ...typography.metaSmall,
    color: colors.text,
    fontWeight: '600',
  },
  footer: {
    flexDirection: 'row',
    gap: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.divider,
    marginTop: spacing.xs,
  },
});
