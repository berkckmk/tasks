import { db } from "./admin";

/** Users fetched per page. Keeps peak memory flat regardless of user count. */
const USER_PAGE_SIZE = 200;

export interface ForEachUserResult {
  processed: number;
  failed: number;
}

/**
 * Walks every user document, applying [handler] to each one.
 *
 * Two things this does that a plain `collection("users").get()` loop did not:
 *
 *  - **Pagination.** The old version loaded every user document into memory
 *    at once. This walks pages of [USER_PAGE_SIZE] ordered by document id,
 *    so memory stays flat and the cursor is stable across pages.
 *
 *  - **Per-user error isolation.** The old loop had no try/catch, so one bad
 *    document took down the whole run and every user after it silently got
 *    nothing. (The concrete case: `timezone` is written by the client, and
 *    `Intl.DateTimeFormat` throws a RangeError on values like "GMT+3" — one
 *    such profile stopped notifications for everybody.) Failures are logged
 *    and counted; the scan continues.
 *
 * This is still a full scan. It's the right shape at this app's size, but
 * if the user count grows past a single run's budget, the next step is to
 * fan out one Pub/Sub message per page rather than to widen the timeout.
 */
export async function forEachUser(
  handler: (userDoc: FirebaseFirestore.QueryDocumentSnapshot) => Promise<void>
): Promise<ForEachUserResult> {
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let failed = 0;

  for (;;) {
    let query = db.collection("users").orderBy("__name__").limit(USER_PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);

    const page = await query.get();
    if (page.empty) break;

    for (const userDoc of page.docs) {
      try {
        await handler(userDoc);
        processed++;
      } catch (error) {
        failed++;
        console.error(`Skipping user ${userDoc.id}:`, error);
      }
    }

    if (page.size < USER_PAGE_SIZE) break;
    cursor = page.docs[page.size - 1];
  }

  if (failed > 0) console.warn(`Run finished with ${failed} failed user(s) of ${processed + failed}.`);
  return { processed, failed };
}
