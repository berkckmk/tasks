import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";
import { Readable } from "stream";

import { db } from "../lib/admin";
import { assertPlan } from "../lib/plan";
import { googleSecrets } from "../lib/secrets";
import { getAuthorizedClient } from "./oauth";

const BACKUP_COLLECTIONS = [
  "habits",
  "habit_logs",
  "tasks",
  "goals",
  "finance_transactions",
  "savings_goals",
  "workouts",
  "exercise_logs",
  "learning_items",
  "content_items",
];

export const backupToGoogleDrive = onCall(
  { secrets: googleSecrets, memory: "1GiB", timeoutSeconds: 540 },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertPlan(uid, ["complete"]);

  const oauthClient = await getAuthorizedClient(uid, "drive");
  const drive = google.drive({ version: "v3", auth: oauthClient });

  const integrationRef = db.collection("users").doc(uid).collection("integrations").doc("google_drive");

  try {
    const existing = await integrationRef.get();
    let folderId = existing.data()?.folderId as string | undefined;

    if (!folderId) {
      // `drive.file` scope means this app can only see files/folders it
      // creates itself — this call creates the one dedicated app folder.
      const folder = await drive.files.create({
        requestBody: { name: "Steady Progress Backups", mimeType: "application/vnd.google-apps.folder" },
        fields: "id",
      });
      folderId = folder.data.id ?? undefined;
      if (!folderId) throw new HttpsError("internal", "Failed to create backup folder.");

      // Persisted immediately, not at the end with the rest of the result.
      // If the backup itself then failed (quota, timeout, OOM), the folder
      // id was lost and the next attempt created another one — a user
      // retrying a failing backup accumulated "Steady Progress Backups"
      // folders in their Drive without limit.
      await integrationRef.set({ folderId }, { merge: true });
    }

    const backup: Record<string, unknown[]> = {};
    for (const collectionName of BACKUP_COLLECTIONS) {
      const snapshot = await db.collection("users").doc(uid).collection(collectionName).get();
      backup[collectionName] = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    }

    const fileName = `backup-${new Date().toISOString().slice(0, 10)}.json`;
    const created = await drive.files.create({
      requestBody: { name: fileName, parents: [folderId] },
      media: { mimeType: "application/json", body: Readable.from(JSON.stringify(backup, null, 2)) },
      fields: "id",
    });

    const folderUrl = `https://drive.google.com/drive/folders/${folderId}`;
    await integrationRef.set(
      {
        enabled: true,
        status: "connected",
        folderId,
        folderUrl,
        lastBackupAt: new Date(),
        errorMessage: null,
      },
      { merge: true }
    );

    return { folderUrl, fileId: created.data.id };
  } catch (error) {
    await integrationRef.set(
      { status: "error", errorMessage: error instanceof Error ? error.message : "Backup failed." },
      { merge: true }
    );
    throw error;
  }
});
