import { db } from "./admin";

/**
 * Refresh tokens live in `users/{uid}/secureTokens/{integration}` — a
 * collection with `allow read, write: if false` in firestore.rules, so only
 * the Admin SDK (i.e. this backend) can ever touch it. The client never
 * sees a refresh token, only the connected/disconnected status in
 * `users/{uid}/integrations/{integration}`.
 */
export interface StoredTokens {
  refreshToken: string;
  accessToken?: string;
  scope: string;
}

function tokensDoc(uid: string, integration: string) {
  return db.collection("users").doc(uid).collection("secureTokens").doc(integration);
}

export async function saveTokens(
  uid: string,
  integration: string,
  tokens: StoredTokens
): Promise<void> {
  await tokensDoc(uid, integration).set(tokens, { merge: true });
}

export async function getTokens(uid: string, integration: string): Promise<StoredTokens | null> {
  const snapshot = await tokensDoc(uid, integration).get();
  return snapshot.exists ? (snapshot.data() as StoredTokens) : null;
}

export async function deleteTokens(uid: string, integration: string): Promise<void> {
  await tokensDoc(uid, integration).delete();
}
