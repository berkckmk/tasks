export type WebPermissionState = 'granted' | 'denied' | 'default' | 'unsupported';

export function isWebNotificationSupported(): boolean {
  return typeof window !== 'undefined' && 'Notification' in window;
}

export function getWebNotificationPermission(): WebPermissionState {
  if (!isWebNotificationSupported()) return 'unsupported';
  return Notification.permission;
}

export async function requestWebNotificationPermission(): Promise<WebPermissionState> {
  if (!isWebNotificationSupported()) return 'unsupported';
  if (Notification.permission === 'granted') return 'granted';
  try {
    const result = await Notification.requestPermission();
    return result;
  } catch {
    return 'denied';
  }
}

/** Play a clean, gentle dual-tone notification chime using Web Audio API */
export function playWebNotificationSound(): void {
  if (typeof window === 'undefined') return;
  try {
    const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    const now = ctx.currentTime;

    const playTone = (freq: number, start: number, duration: number) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, start);

      gain.gain.setValueAtTime(0, start);
      gain.gain.linearRampToValueAtTime(0.18, start + 0.03);
      gain.gain.exponentialRampToValueAtTime(0.001, start + duration);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(start);
      osc.stop(start + duration);
    };

    // Soft chime chord: D5 (587.33Hz) followed by A5 (880Hz)
    playTone(587.33, now, 0.35);
    playTone(880.00, now + 0.08, 0.45);
  } catch {
    // Audio playback policy or unsupported Web Audio
  }
}

export function sendWebNotification(
  title: string,
  options?: {
    body?: string;
    tag?: string;
    onClick?: () => void;
    silent?: boolean;
  },
): Notification | null {
  if (!isWebNotificationSupported() || Notification.permission !== 'granted') {
    return null;
  }

  try {
    const notification = new Notification(title, {
      body: options?.body ?? '',
      icon: '/app-icon.png',
      badge: '/app-icon.png',
      tag: options?.tag,
    });

    notification.onclick = () => {
      window.focus();
      options?.onClick?.();
      notification.close();
    };

    if (!options?.silent) {
      playWebNotificationSound();
    }

    return notification;
  } catch (err) {
    console.warn('[WEB_NOTIFICATION_ERROR]', err);
    return null;
  }
}
