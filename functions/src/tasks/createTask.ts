import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/admin";
import { getUserPlanId } from "../lib/plan";
import {
  MAX_DESCRIPTION_LENGTH,
  MAX_ID_LENGTH,
  MAX_TITLE_LENGTH,
  optionalString,
  requireEnum,
  requireString,
} from "../lib/validate";

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
 * collection, so this function counts it server-side before allowing the
 * write.
 *
 * Known gap: the cap is enforced at creation only. `update` on an existing
 * task is client-direct (rules allow it, and it can't create a document), so
 * a Starter user could park 20 tasks as `done`, create 20 more, then flip
 * the first 20 back to `todo` and end up over the limit. Closing that needs
 * an onDocumentUpdated trigger firing on every task edit, which costs an
 * invocation per keystroke-save for a limit that only binds on the free
 * tier. Worth doing if Starter ever becomes a meaningful share of usage —
 * it is not enforced today.
 */
export const createTask = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const data = request.data as Record<string, unknown>;
  const title = requireString(data.title, "title", MAX_TITLE_LENGTH);
  const priority = requireEnum(data.priority, "priority", VALID_PRIORITIES);
  const description = optionalString(data.description, "description", MAX_DESCRIPTION_LENGTH) ?? "";
  const relatedGoalId = optionalString(data.relatedGoalId, "relatedGoalId", MAX_ID_LENGTH);

  const parseDate = (value: unknown, field: string): Date | null => {
    if (typeof value !== "string") return null;
    const candidate = new Date(value);
    if (Number.isNaN(candidate.getTime())) {
      throw new HttpsError("invalid-argument", `Invalid ${field}.`);
    }
    return candidate;
  };

  const parsedDueDate = parseDate(data.dueDate, "dueDate");
  // The first day of the task's range. `dueDate` stays the last day and the
  // deadline, so a single-day task has both set to the same date and every
  // existing reader keeps working unchanged.
  const parsedStartDate = parseDate(data.startDate, "startDate");
  if (parsedStartDate && parsedDueDate && parsedStartDate > parsedDueDate) {
    throw new HttpsError("invalid-argument", "startDate must not be after dueDate.");
  }
  // No clock time was chosen, so the task is on the day rather than at a
  // moment. Absent defaults to true, which is what every task written before
  // this field existed was.
  const allDay = typeof data.allDay === "boolean" ? data.allDay : true;

  const tasksRef = db.collection("users").doc(uid).collection("tasks");
  const planId = await getUserPlanId(uid);
  const now = new Date();
  const docRef = tasksRef.doc();

  await db.runTransaction(async (tx) => {
    // See createHabit.ts for why this counts documents inside a transaction
    // rather than using an aggregation query: read-then-write let N
    // concurrent calls all observe the same under-limit count and all
    // succeed.
    if (planId === "starter") {
      const existing = await tx.get(
        tasksRef.where("status", "in", ACTIVE_STATUSES).select().limit(STARTER_TASK_LIMIT + 1)
      );
      if (existing.size >= STARTER_TASK_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          `The Starter plan allows up to ${STARTER_TASK_LIMIT} active tasks. Upgrade to Growth for unlimited tasks.`
        );
      }
    }

    tx.create(docRef, {
      title,
      description,
      startDate: parsedStartDate,
      dueDate: parsedDueDate,
      allDay,
      priority,
      status: "todo",
      relatedGoalId,
      createdAt: now,
      updatedAt: now,
    });
  });

  return { id: docRef.id };
});
