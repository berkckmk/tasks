import { setActiveNavBarSlots } from '@/theme';
import type { DataGateway } from '@/core/data/data-gateway';
import {
  DEFAULT_NAVBAR_SLOTS,
  sanitizeNavbarSlots,
  type NavSlotId,
} from './navbar-items';

const LOCAL_STORAGE_KEY = 'steady_progress_navbar_slots_v1';

let inMemorySlots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [...DEFAULT_NAVBAR_SLOTS];
setActiveNavBarSlots(inMemorySlots);

export function loadSlotsLocal(): [NavSlotId, NavSlotId, NavSlotId, NavSlotId] {
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      const stored = window.localStorage.getItem(LOCAL_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        inMemorySlots = sanitizeNavbarSlots(parsed);
        setActiveNavBarSlots(inMemorySlots);
        return inMemorySlots;
      }
    } catch {
      // Fall through to memory slots
    }
  }
  setActiveNavBarSlots(inMemorySlots);
  return inMemorySlots;
}

export function saveSlotsLocal(slots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId]): void {
  inMemorySlots = [...slots];
  setActiveNavBarSlots(inMemorySlots);
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      window.localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(slots));
    } catch {
      // Ignore storage errors
    }
  }
}

export async function saveSlotsRemote(
  gateway: DataGateway | null | undefined,
  userId: string | null | undefined,
  slots: [NavSlotId, NavSlotId, NavSlotId, NavSlotId],
): Promise<void> {
  saveSlotsLocal(slots);
  if (!gateway || !userId) return;

  try {
    await gateway.setDocument(
      `users/${userId}`,
      {
        appPreferences: {
          navBarSlots: slots,
        },
      },
      { merge: true },
    );
  } catch {
    // Graceful offline fallback
  }
}
