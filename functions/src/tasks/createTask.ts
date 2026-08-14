import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/admin";
import { getUserPlanId } from "../lib/plan";

const STARTER_TASK_LIMIT = 20;
const VALID_PRIORITIES = ["low", "medium", "high"];
// "Active" mirrors PlanEnforcement.activeTaskCount on the Flutter side
// (features/subscription/application/subscription_providers.dart), which
// counts everything that isn't done.
const ACTIVE_STATUSES = ["todo", "inProgress"];

/**
 * The only path that can create a task — firestore.rules denies `create`
 * on `users/{uid}/tasks/{taskId}` outright (see the comment there). Same
 * rationale as createHabit.ts: Starter caps active tasks at 20
 * (lib/features/pricing/data/plan_catalog.dart), and rules can't count a
 * collection, so this function counts it server-side with an aggregation
 * query before allowing the write.
 */
export const createTask = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { title, description, dueDate, priority, relatedGoalId } = request.data as {
    title?: unknown;
    description?: unknown;
    dueDate?: unknown;
    priority?: unknown;
    relatedGoalId?: unknown;
  };

  if (typeof title !== "string" || title.trim().length === 0) {
    throw new HttpsError("invalid-argument", "title is required.");
  }
  if (typeof priority !== "string" || !VALID_PRIORITIES.includes(priority)) {
    throw new HttpsError("invalid-argument", "Invalid priority.");
  }
  let parsedDueDate: Date | null = null;
  if (typeof dueDate === "string") {
    const candidate = new Date(dueDate);
    if (Number.isNaN(candidate.getTime())) {
      throw new HttpsError("invalid-argument", "Invalid dueDate.");
    }
    parsedDueDate = candidate;
  }

  const tasksRef = db.collection("users").doc(uid).collection("tasks");

  const planId = await getUserPlanId(uid);
  if (planId === "starter") {
    const countSnapshot = await tasksRef.where("status", "in", ACTIVE_STATUSES).count().get();
    if (countSnapshot.data().count >= STARTER_TASK_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        `The Starter plan allows up to ${STARTER_TASK_LIMIT} active tasks. Upgrade to Growth for unlimited tasks.`
      );
    }
  }

  const now = new Date();
  const docRef = await tasksRef.add({
    title: title.trim(),
    description: typeof description === "string" ? description.trim() : "",
    dueDate: parsedDueDate,
    priority,
    status: "todo",
    relatedGoalId: typeof relatedGoalId === "string" ? relatedGoalId : null,
    createdAt: now,
    updatedAt: now,
  });

  return { id: docRef.id };
});
