import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google, sheets_v4 } from "googleapis";

import { db } from "../lib/admin";
import { assertPlan } from "../lib/plan";
import { googleSecrets } from "../lib/secrets";
import { getAuthorizedClient } from "./oauth";

const MODULE_COLLECTIONS: Record<string, string> = {
  Habits: "habits",
  "Habit Logs": "habit_logs",
  Tasks: "tasks",
  Goals: "goals",
  Finance: "finance_transactions",
  Workouts: "workouts",
  Learning: "learning_items",
  Content: "content_items",
};

export const exportToGoogleSheets = onCall(
  { secrets: googleSecrets, memory: "512MiB", timeoutSeconds: 300 },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertPlan(uid, ["complete"]);

  const { modules } = request.data as { modules?: unknown };
  const selected =
    Array.isArray(modules) && modules.length > 0
      ? (modules as string[]).filter((m) => m in MODULE_COLLECTIONS)
      : Object.keys(MODULE_COLLECTIONS);

  const oauthClient = await getAuthorizedClient(uid, "sheets");
  const sheets = google.sheets({ version: "v4", auth: oauthClient });

  const integrationRef = db.collection("users").doc(uid).collection("integrations").doc("google_sheets");

  try {
    const spreadsheetId = await ensureSpreadsheet(sheets, integrationRef);

    for (const moduleName of selected) {
      const collectionName = MODULE_COLLECTIONS[moduleName];
      const snapshot = await db.collection("users").doc(uid).collection(collectionName).get();
      const rows = snapshot.docs.map((doc) => flattenForSheet({ id: doc.id, ...doc.data() }));
      // Union of keys across every row, not just the first one. Documents in
      // these collections are heterogeneous (optional fields, fields added
      // over time), so deriving the header from rows[0] silently dropped any
      // column the first document happened not to have.
      const header = ["id", ...unionOfKeys(rows).filter((key) => key !== "id")];
      const values = [header, ...rows.map((row) => header.map((key) => cellValue(row[key])))];

      await ensureSheetTab(sheets, spreadsheetId, moduleName);
      await sheets.spreadsheets.values.update({
        spreadsheetId,
        range: `${moduleName}!A1`,
        valueInputOption: "RAW",
        requestBody: { values },
      });
    }

    const spreadsheetUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}`;
    await integrationRef.set(
      {
        enabled: true,
        status: "connected",
        spreadsheetId,
        spreadsheetUrl,
        lastExportedAt: new Date(),
        selectedModules: selected,
        errorMessage: null,
      },
      { merge: true }
    );

    return { spreadsheetUrl };
  } catch (error) {
    await integrationRef.set(
      { status: "error", errorMessage: error instanceof Error ? error.message : "Export failed." },
      { merge: true }
    );
    throw error;
  }
});

async function ensureSpreadsheet(
  sheets: sheets_v4.Sheets,
  integrationRef: FirebaseFirestore.DocumentReference
): Promise<string> {
  const existing = await integrationRef.get();
  const existingId = existing.data()?.spreadsheetId as string | undefined;
  if (existingId) return existingId;

  const created = await sheets.spreadsheets.create({
    requestBody: { properties: { title: "Steady Progress Export" } },
  });
  const spreadsheetId = created.data.spreadsheetId;
  if (!spreadsheetId) throw new HttpsError("internal", "Failed to create spreadsheet.");

  // Stored right away rather than with the rest of the result at the end: a
  // failure mid-export otherwise orphaned this spreadsheet and the next
  // attempt created a fresh one.
  await integrationRef.set({ spreadsheetId }, { merge: true });
  return spreadsheetId;
}

async function ensureSheetTab(
  sheets: sheets_v4.Sheets,
  spreadsheetId: string,
  title: string
): Promise<void> {
  const meta = await sheets.spreadsheets.get({ spreadsheetId });
  const exists = meta.data.sheets?.some((s) => s.properties?.title === title);
  if (!exists) {
    await sheets.spreadsheets.batchUpdate({
      spreadsheetId,
      requestBody: { requests: [{ addSheet: { properties: { title } } }] },
    });
  }
}

/** Every key present on any row, in first-seen order. */
function unionOfKeys(rows: Record<string, unknown>[]): string[] {
  const keys = new Set<string>();
  for (const row of rows) {
    for (const key of Object.keys(row)) keys.add(key);
  }
  return [...keys];
}

/** Sheets rejects cells longer than 50,000 characters. */
const MAX_CELL_LENGTH = 50000;

function cellValue(value: unknown): string {
  const text = String(value ?? "");
  return text.length > MAX_CELL_LENGTH ? `${text.slice(0, MAX_CELL_LENGTH - 3)}...` : text;
}

function flattenForSheet(data: Record<string, unknown>): Record<string, unknown> {
  const flat: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof (value as { toDate?: unknown }).toDate === "function") {
      flat[key] = (value as FirebaseFirestore.Timestamp).toDate().toISOString();
    } else if (value && typeof value === "object") {
      flat[key] = JSON.stringify(value);
    } else {
      flat[key] = value;
    }
  }
  return flat;
}
