import { HttpsError } from "firebase-functions/v2/https";

/**
 * Field length caps.
 *
 * Callables previously checked type and non-emptiness but never a maximum,
 * so any string could be up to Firestore's 1MiB document limit. That isn't
 * only a storage cost: those strings are later read into memory by the
 * reminder scan, JSON-stringified whole into `backupToGoogleDrive`'s single
 * in-memory buffer, and written into Sheets cells, which reject anything
 * over 50k characters — so one oversized habit name breaks an unrelated
 * export for the whole account.
 */
export const MAX_TITLE_LENGTH = 200;
export const MAX_DESCRIPTION_LENGTH = 2000;
export const MAX_LABEL_LENGTH = 60;
export const MAX_ID_LENGTH = 128;

/** A required, non-empty, length-capped string. Returns it trimmed. */
export function requireString(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  if (trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} must be ${maxLength} characters or fewer.`);
  }
  return trimmed;
}

/** An optional, length-capped string. Returns null when absent. */
export function optionalString(value: unknown, field: string, maxLength: number): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} must be ${maxLength} characters or fewer.`);
  }
  return trimmed;
}

/**
 * A finite number. `typeof NaN === "number"`, so the plain typeof check this
 * replaces let NaN and Infinity through into stored documents.
 */
export function requireFiniteNumber(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${field} must be a finite number.`);
  }
  return value;
}

/** One of [allowed]. */
export function requireEnum(value: unknown, field: string, allowed: readonly string[]): string {
  if (typeof value !== "string" || !allowed.includes(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return value;
}
