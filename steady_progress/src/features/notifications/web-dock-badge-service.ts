/**
 * Manages the macOS Dock / Taskbar badge counter (App Badge API).
 * Supported in Safari (PWA on macOS Sonoma/Ventura), Chrome, Edge.
 */

export function isAppBadgeSupported(): boolean {
  return typeof navigator !== 'undefined' && 'setAppBadge' in navigator;
}

export async function updateDockBadge(count: number): Promise<void> {
  if (!isAppBadgeSupported()) return;
  try {
    if (count > 0) {
      await navigator.setAppBadge(count);
    } else {
      await navigator.clearAppBadge();
    }
  } catch {
    // Unsupported or permission restricted
  }
}

export async function clearDockBadge(): Promise<void> {
  if (!isAppBadgeSupported()) return;
  try {
    await navigator.clearAppBadge();
  } catch {
    // Safe no-op
  }
}
