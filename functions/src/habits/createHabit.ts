import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/admin";
import { clientMutationDocumentId } from "../lib/clientMutation";
import { parseReminderTime } from "../lib/datetime";
import { getUserPlanId } from "../lib/plan";
import {
  MAX_LABEL_LENGTH,
  MAX_ID_LENGTH,
  MAX_TITLE_LENGTH,
  optionalString,
  requireEnum,
  requireFiniteNumber,
  requireString,
} from "../lib/validate";

const STARTER_HABIT_LIMIT = 3;
const VALID_CATEGORIES = ["morning", "evening", "health", "work"];

/**
 * The only path that can create a habit — firestore.rules denies `create`
 * on `users/{uid}/habits/{habitId}` outright (see the comment there).
 *
 * Why: the Starter plan caps active habits at 3
 * (lib/features/pricing/data/plan_catalog.dart), and PlanEnforcement only
 * hides the "add habit" button client-side — it can't stop a signed-in user
 * from writing a 4th habit doc directly with their own valid credentials.
 * Firestore security rules have no way to count a collection's size, so
 * there's no rule that could enforce this directly. Routing creation
 * through this function lets us count the real `habits` collection and
 * reject the write server-side before it happens.
 */
export const createHabit = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const data = request.data as Record<string, unknown>;
  const name = requireString(data.name, "name", MAX_TITLE_LENGTH);
  const category = requireEnum(data.category, "category", VALID_CATEGORIES);
  const frequencyLabel = requireString(data.frequencyLabel, "frequencyLabel", MAX_LABEL_LENGTH);
  const colorValue = requireFiniteNumber(data.colorValue, "colorValue");
  const reminderTimeLabel = optionalString(
    data.reminderTimeLabel,
    "reminderTimeLabel",
    MAX_LABEL_LENGTH
  );
  const clientMutationId = optionalString(data.clientMutationId, "clientMutationId", MAX_ID_LENGTH);
  // Rejected here rather than stored and dealt with later: an unparseable
  // label like "99:99" used to reach the calendar sync, where setHours(99, 99)
  // rolled the reminder event four days into the future.
  if (reminderTimeLabel !== null && !parseReminderTime(reminderTimeLabel)) {
    throw new HttpsError("invalid-argument", "reminderTimeLabel must look like 09:00 or 9:00 AM.");
  }

  const habitsRef = db.collection("users").doc(uid).collection("habits");
  const planId = await getUserPlanId(uid);
  const now = new Date();
  const docRef = clientMutationId
    ? habitsRef.doc(clientMutationDocumentId(clientMutationId))
    : habitsRef.doc();

  await db.runTransaction(async (tx) => {
    // A retry must return the document created by the first attempt rather
    // than consuming another plan slot or creating a duplicate habit.
    if (clientMutationId && (await tx.get(docRef)).exists) return;

    // Counted inside the transaction, so concurrent creates can't each read
    // "2 habits" and all succeed. An aggregation query (.count()) can't take
    // part in a transaction, so this reads at most LIMIT + 1 document refs
    // instead — cheap at these limits, and unlike a denormalised counter
    // there's nothing that can drift out of sync with reality.
    if (planId === "starter") {
      const existing = await tx.get(habitsRef.select().limit(STARTER_HABIT_LIMIT + 1));
      if (existing.size >= STARTER_HABIT_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          `The Starter plan allows up to ${STARTER_HABIT_LIMIT} active habits. Upgrade to Growth for unlimited habits.`
        );
      }
    }

    tx.create(docRef, {
      name,
      category,
      frequencyLabel,
      colorValue,
      reminderTimeLabel,
      ...(clientMutationId ? { clientMutationId } : {}),
      createdAt: now,
      updatedAt: now,
    });
  });

  return { id: docRef.id };
});
