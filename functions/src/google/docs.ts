import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";

import { db } from "../lib/admin";
import { assertPlan } from "../lib/plan";
import { getAuthorizedClient } from "./oauth";

interface ReportSummary {
  habitCompletionRate: number;
  tasksCompleted: number;
  tasksTotal: number;
  goalProgressAverage: number;
  workoutCount: number;
  learningItemsCompleted: number;
}

export const generateGoogleDocsReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertPlan(uid, ["complete"]);

  const { type, periodStart, periodEnd } = request.data as {
    type?: unknown;
    periodStart?: unknown;
    periodEnd?: unknown;
  };
  if (type !== "weekly" && type !== "monthly") {
    throw new HttpsError("invalid-argument", "type must be 'weekly' or 'monthly'.");
  }
  const start = new Date(periodStart as string);
  const end = new Date(periodEnd as string);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    throw new HttpsError("invalid-argument", "Invalid periodStart/periodEnd.");
  }

  const userRef = db.collection("users").doc(uid);
  const reportRef = userRef.collection("reports").doc();
  await reportRef.set({
    type,
    periodStart: start,
    periodEnd: end,
    createdAt: new Date(),
    status: "generating",
  });

  try {
    const oauthClient = await getAuthorizedClient(uid, "docs");
    const docs = google.docs({ version: "v1", auth: oauthClient });

    const summary = await buildSummary(uid, start, end);

    const created = await docs.documents.create({
      requestBody: { title: `Steady Progress ${type} report` },
    });
    const documentId = created.data.documentId;
    if (!documentId) throw new HttpsError("internal", "Failed to create document.");

    await docs.documents.batchUpdate({
      documentId,
      requestBody: { requests: buildReportContentRequests(summary) },
    });

    const googleDocUrl = `https://docs.google.com/document/d/${documentId}`;
    await reportRef.update({ status: "ready", googleDocId: documentId, googleDocUrl });
    await userRef
      .collection("integrations")
      .doc("google_docs")
      .set(
        { enabled: true, status: "connected", lastReportGeneratedAt: new Date(), errorMessage: null },
        { merge: true }
      );

    return { reportId: reportRef.id, googleDocUrl };
  } catch (error) {
    await reportRef.update({ status: "failed" });
    await userRef
      .collection("integrations")
      .doc("google_docs")
      .set(
        { status: "error", errorMessage: error instanceof Error ? error.message : "Report failed." },
        { merge: true }
      );
    throw error;
  }
});

async function buildSummary(uid: string, start: Date, end: Date): Promise<ReportSummary> {
  const userRef = db.collection("users").doc(uid);

  const [habitsSnapshot, logsSnapshot, tasksSnapshot, goalsSnapshot, workoutsSnapshot, learningSnapshot] =
    await Promise.all([
      userRef.collection("habits").get(),
      userRef
        .collection("habit_logs")
        .where("date", ">=", start.toISOString().slice(0, 10))
        .where("date", "<=", end.toISOString().slice(0, 10))
        .get(),
      userRef.collection("tasks").get(),
      userRef.collection("goals").get(),
      userRef.collection("workouts").get(),
      userRef.collection("learning_items").get(),
    ]);

  const completedLogs = logsSnapshot.docs.filter((doc) => doc.data().completed === true).length;
  const possibleLogs = habitsSnapshot.size * daysBetween(start, end);
  const habitCompletionRate = possibleLogs === 0 ? 0 : completedLogs / possibleLogs;

  const tasksInRange = tasksSnapshot.docs.filter((doc) => {
    const due = (doc.data().dueDate as FirebaseFirestore.Timestamp | undefined)?.toDate();
    return due && due >= start && due <= end;
  });
  const tasksCompleted = tasksInRange.filter((doc) => doc.data().status === "done").length;

  const goalProgressAverage =
    goalsSnapshot.size === 0
      ? 0
      : goalsSnapshot.docs.reduce(
          (sum, doc) => sum + ((doc.data().manualProgress as number | undefined) ?? 0),
          0
        ) / goalsSnapshot.size;

  const workoutCount = workoutsSnapshot.docs.filter((doc) => {
    const date = (doc.data().date as FirebaseFirestore.Timestamp | undefined)?.toDate();
    return date && date >= start && date <= end;
  }).length;

  const learningItemsCompleted = learningSnapshot.docs.filter(
    (doc) => doc.data().status === "completed"
  ).length;

  return {
    habitCompletionRate,
    tasksCompleted,
    tasksTotal: tasksInRange.length,
    goalProgressAverage,
    workoutCount,
    learningItemsCompleted,
  };
}

function daysBetween(start: Date, end: Date): number {
  return Math.max(1, Math.round((end.getTime() - start.getTime()) / 86_400_000) + 1);
}

function buildReportContentRequests(summary: ReportSummary): Record<string, unknown>[] {
  const lines = [
    "Steady Progress Report",
    "",
    `Habit completion: ${Math.round(summary.habitCompletionRate * 100)}%`,
    `Tasks completed: ${summary.tasksCompleted} / ${summary.tasksTotal}`,
    `Average goal progress: ${Math.round(summary.goalProgressAverage * 100)}%`,
    `Workouts logged: ${summary.workoutCount}`,
    `Learning items completed: ${summary.learningItemsCompleted}`,
    "",
    "Reflection prompts:",
    "- What's one habit that felt easiest to keep this period?",
    "- What got in the way of the tasks you didn't finish?",
    "- What's the smallest next step toward your top goal?",
  ];
  return [{ insertText: { location: { index: 1 }, text: lines.join("\n") } }];
}
