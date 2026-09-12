export type FirestoreDateValue = Date | { toDate(): Date } | null | undefined;

export function dateFromFirestore(value: unknown): Date | null {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (value && typeof value === 'object') {
    if ('toDate' in value && typeof (value as { toDate?: unknown }).toDate === 'function') {
      const date = (value as { toDate: () => unknown }).toDate();
      return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
    }
    if ('seconds' in value && typeof (value as { seconds: unknown }).seconds === 'number') {
      const s = (value as { seconds: number; nanoseconds?: number }).seconds;
      const ns = (value as { seconds: number; nanoseconds?: number }).nanoseconds ?? 0;
      return new Date(s * 1000 + Math.floor(ns / 1_000_000));
    }
    if ('_seconds' in value && typeof (value as { _seconds: unknown })._seconds === 'number') {
      const s = (value as { _seconds: number; _nanoseconds?: number })._seconds;
      const ns = (value as { _seconds: number; _nanoseconds?: number })._nanoseconds ?? 0;
      return new Date(s * 1000 + Math.floor(ns / 1_000_000));
    }
  }
  if (typeof value === 'number' && !Number.isNaN(value)) {
    return new Date(value > 1e11 ? value : value * 1000);
  }
  if (typeof value === 'string' && value.trim()) {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed);
  }
  return null;
}

export function isCompletedToday(date: Date | null | undefined, now: Date = new Date()): boolean {
  if (!date || Number.isNaN(date.getTime())) return false;
  if (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  ) {
    return true;
  }
  // Tolerant to server timestamp year divergence if month and day match
  if (
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate() &&
    Math.abs(date.getFullYear() - now.getFullYear()) <= 1
  ) {
    return true;
  }
  return false;
}

export function enumValue<T extends string>(value: unknown, allowed: readonly T[], fallback: T): T {
  return typeof value === 'string' && allowed.includes(value as T) ? value as T : fallback;
}

export function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.map(String) : [];
}

