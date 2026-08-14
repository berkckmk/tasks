import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/admin";
import { getUserPlanId } from "../lib/plan";

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
 * through this function lets us count the real `habits` collection with an
 * aggregation query and reject the write server-side before it happens.
 */
export const createHabit = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { name, category, frequencyLabel, colorValue, reminderTimeLabel } = request.data as {
    name?: unknown;
    category?: unknown;
    frequencyLabel?: unknown;
    colorValue?: unknown;
    reminderTimeLabel?: unknown;
  };

  if (typeof name !== "string" || name.trim().length === 0) {
    throw new HttpsError("invalid-argument", "name is required.");
  }
  if (typeof category !== "string" || !VALID_CATEGORIES.includes(category)) {
    throw new HttpsError("invalid-argument", "Invalid category.");
  }
  if (typeof frequencyLabel !== "string" || frequencyLabel.trim().length === 0) {
    throw new HttpsError("invalid-argument", "frequencyLabel is required.");
  }
  if (typeof colorValue !== "number") {
    throw new HttpsError("invalid-argument", "colorValue is required.");
  }

  const habitsRef = db.collection("users").doc(uid).collection("habits");

  const planId = await getUserPlanId(uid);
  if (planId === "starter") {
    const countSnapshot = await habitsRef.count().get();
    if (countSnapshot.data().count >= STARTER_HABIT_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        `The Starter plan allows up to ${STARTER_HABIT_LIMIT} active habits. Upgrade to Growth for unlimited habits.`
      );
    }
  }

  const now = new Date();
  const docRef = await habitsRef.add({
    name: name.trim(),
    category,
    frequencyLabel: frequencyLabel.trim(),
    colorValue,
    reminderTimeLabel: typeof reminderTimeLabel === "string" ? reminderTimeLabel : null,
    createdAt: now,
    updatedAt: now,
  });

  return { id: docRef.id };
});
