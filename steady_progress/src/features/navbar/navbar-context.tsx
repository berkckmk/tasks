import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type PropsWithChildren,
} from 'react';
import { useAppData } from '@/core/data/app-data';
import {
  DEFAULT_NAVBAR_SLOTS,
  FIXED_MORE_SLOT,
  SELECTABLE_TRACKING_ITEMS,
  sanitizeNavbarSlots,
  type NavSlotId,
} from './navbar-items';
import { loadSlotsLocal, saveSlotsLocal, saveSlotsRemote } from './navbar-storage';

interface NavBarContextValue {
  slots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId];
  allTabs: [NavSlotId, NavSlotId, NavSlotId, NavSlotId, typeof FIXED_MORE_SLOT];
  isConfigModalOpen: boolean;
  activeEditSlotIndex: number | null;
  openConfigModal: (targetSlotIndex?: number) => void;
  closeConfigModal: () => void;
  setActiveEditSlotIndex: (index: number | null) => void;
  updateSlots: (newSlots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId]) => Promise<void>;
  replaceSlot: (slotIndex: number, newId: NavSlotId) => Promise<void>;
  removeSlot: (slotIndex: number) => Promise<void>;
  resetToDefaults: () => Promise<void>;
  isSlotInNavbar: (id: NavSlotId) => boolean;
}

const NavBarContext = createContext<NavBarContextValue | null>(null);

function useSafeAppData() {
  try {
    return useAppData();
  } catch {
    return null;
  }
}

import { setActiveNavBarSlots } from '@/theme';

export function NavBarProvider({ children }: PropsWithChildren) {
  const appData = useSafeAppData();
  const [slots, setSlots] = useState<[NavSlotId, NavSlotId, NavSlotId, NavSlotId]>(() => {
    const initial = loadSlotsLocal();
    setActiveNavBarSlots(initial);
    return initial;
  });
  const [isConfigModalOpen, setIsConfigModalOpen] = useState(false);
  const [activeEditSlotIndex, setActiveEditSlotIndex] = useState<number | null>(null);

  useEffect(() => {
    setActiveNavBarSlots(slots);
  }, [slots]);

  // Watch remote document if appData is available
  useEffect(() => {
    if (!appData?.gateway || !appData?.userId) return;

    const stop = appData.gateway.watchDocument(
      `users/${appData.userId}`,
      (row) => {
        const data = row?.data ?? {};
        const prefs =
          data.appPreferences && typeof data.appPreferences === 'object' && !Array.isArray(data.appPreferences)
            ? (data.appPreferences as Record<string, unknown>)
            : {};

        if (Array.isArray(prefs.navBarSlots)) {
          const validated = sanitizeNavbarSlots(prefs.navBarSlots);
          setSlots(validated);
          saveSlotsLocal(validated);
        }
      },
      () => {
        // Fall back gracefully on watch error
      },
    );

    return () => {
      stop();
    };
  }, [appData?.gateway, appData?.userId]);

  const openConfigModal = useCallback((targetSlotIndex?: number) => {
    setActiveEditSlotIndex(typeof targetSlotIndex === 'number' ? targetSlotIndex : null);
    setIsConfigModalOpen(true);
  }, []);

  const closeConfigModal = useCallback(() => {
    setIsConfigModalOpen(false);
    setActiveEditSlotIndex(null);
  }, []);

  const updateSlots = useCallback(
    async (newSlots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId]) => {
      const sanitized = sanitizeNavbarSlots(newSlots);
      setSlots(sanitized);
      await saveSlotsRemote(appData?.gateway, appData?.userId, sanitized);
    },
    [appData?.gateway, appData?.userId],
  );

  const replaceSlot = useCallback(
    async (slotIndex: number, newId: NavSlotId) => {
      if (slotIndex < 0 || slotIndex > 3 || newId === FIXED_MORE_SLOT) return;
      const nextSlots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [...slots];

      // If newId is already in another slot, swap them!
      const existingIdx = nextSlots.indexOf(newId);
      if (existingIdx !== -1 && existingIdx !== slotIndex) {
        nextSlots[existingIdx] = nextSlots[slotIndex];
      }
      nextSlots[slotIndex] = newId;

      await updateSlots(nextSlots);
    },
    [slots, updateSlots],
  );

  const removeSlot = useCallback(
    async (slotIndex: number) => {
      if (slotIndex < 0 || slotIndex > 3) return;
      // Find an available item not currently in any slot
      const candidate = SELECTABLE_TRACKING_ITEMS.find((item) => !slots.includes(item.id));
      if (!candidate) return;

      const nextSlots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [...slots];
      nextSlots[slotIndex] = candidate.id;
      await updateSlots(nextSlots);
    },
    [slots, updateSlots],
  );

  const resetToDefaults = useCallback(async () => {
    await updateSlots([...DEFAULT_NAVBAR_SLOTS]);
  }, [updateSlots]);

  const isSlotInNavbar = useCallback(
    (id: NavSlotId) => {
      if (id === FIXED_MORE_SLOT) return true;
      return slots.includes(id);
    },
    [slots],
  );

  const allTabs = useMemo<[NavSlotId, NavSlotId, NavSlotId, NavSlotId, typeof FIXED_MORE_SLOT]>(() => {
    return [slots[0], slots[1], slots[2], slots[3], FIXED_MORE_SLOT];
  }, [slots]);

  const value = useMemo<NavBarContextValue>(
    () => ({
      slots,
      allTabs,
      isConfigModalOpen,
      activeEditSlotIndex,
      openConfigModal,
      closeConfigModal,
      setActiveEditSlotIndex,
      updateSlots,
      replaceSlot,
      removeSlot,
      resetToDefaults,
      isSlotInNavbar,
    }),
    [
      slots,
      allTabs,
      isConfigModalOpen,
      activeEditSlotIndex,
      openConfigModal,
      closeConfigModal,
      updateSlots,
      replaceSlot,
      removeSlot,
      resetToDefaults,
      isSlotInNavbar,
    ],
  );

  return <NavBarContext.Provider value={value}>{children}</NavBarContext.Provider>;
}

export function useNavBar(): NavBarContextValue {
  const context = useContext(NavBarContext);
  if (!context) {
    // Return a standalone fallback with local storage so it functions even if provider is absent
    const fallbackSlots = loadSlotsLocal();
    return {
      slots: fallbackSlots,
      allTabs: [fallbackSlots[0], fallbackSlots[1], fallbackSlots[2], fallbackSlots[3], FIXED_MORE_SLOT],
      isConfigModalOpen: false,
      activeEditSlotIndex: null,
      openConfigModal: () => {},
      closeConfigModal: () => {},
      setActiveEditSlotIndex: () => {},
      updateSlots: async (next) => {
        saveSlotsLocal(next);
      },
      replaceSlot: async () => {},
      removeSlot: async () => {},
      resetToDefaults: async () => {
        saveSlotsLocal([...DEFAULT_NAVBAR_SLOTS]);
      },
      isSlotInNavbar: (id) => id === FIXED_MORE_SLOT || fallbackSlots.includes(id),
    };
  }
  return context;
}
