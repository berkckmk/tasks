import { HttpsError } from "firebase-functions/v2/https";
import { OAuth2Client } from "google-auth-library";

import { getTokens, saveTokens } from "../lib/tokens";

function newOAuthClient(): OAuth2Client {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new HttpsError(
      "failed-precondition",
      "Google OAuth client is not configured on the server. See functions/.env.example."
    );
  }
  return new OAuth2Client(clientId, clientSecret);
}

/**
 * Exchanges a one-time server auth code — obtained on the client via
 * `GoogleSignIn.instance.authorizationClient.authorizeServer([scope])` and
 * sent here as `authCode` — for a refresh token, and stores it. The client
 * never receives or handles the refresh token itself.
 */
export async function exchangeAndStoreCode(
  uid: string,
  integration: string,
  authCode: string,
  scope: string
): Promise<void> {
  const client = newOAuthClient();
  const { tokens } = await client.getToken(authCode);
  if (!tokens.refresh_token) {
    throw new HttpsError(
      "failed-precondition",
      "Google didn't return a refresh token. Revoke prior access at " +
        "https://myaccount.google.com/permissions and try connecting again."
    );
  }
  // Verify the scopes Google actually granted, not the ones we asked for.
  // Storing the requested constant meant the recorded `scope` was a value
  // the server made up: a client could send a code issued for a different
  // scope and have it filed under this integration, and the mismatch would
  // only surface later as an opaque 403 mid-sync.
  const grantedScopes = (tokens.scope ?? "").split(" ").filter((s) => s.length > 0);
  const missing = scope.split(" ").filter((required) => !grantedScopes.includes(required));
  if (missing.length > 0) {
    throw new HttpsError(
      "permission-denied",
      `Google didn't grant the access ${integration} needs (${missing.join(", ")}). ` +
        "Please try connecting again and approve all requested permissions."
    );
  }

  await saveTokens(uid, integration, {
    refreshToken: tokens.refresh_token,
    accessToken: tokens.access_token ?? undefined,
    scope: tokens.scope ?? scope,
  });
}

/**
 * Revokes a refresh token at Google. Best-effort: an already-invalid token
 * is a success from the caller's point of view.
 */
export async function revokeRefreshToken(refreshToken: string): Promise<void> {
  try {
    await newOAuthClient().revokeToken(refreshToken);
  } catch (error) {
    console.warn("Google token revocation failed (continuing with local delete):", error);
  }
}

/**
 * Returns an OAuth2Client pre-loaded with this user's stored refresh token
 * for [integration], ready to pass straight into a googleapis client — the
 * library handles refreshing the short-lived access token automatically.
 */
export async function getAuthorizedClient(uid: string, integration: string): Promise<OAuth2Client> {
  const stored = await getTokens(uid, integration);
  if (!stored) {
    throw new HttpsError("failed-precondition", `${integration} is not connected.`);
  }
  const client = newOAuthClient();
  client.setCredentials({ refresh_token: stored.refreshToken });
  return client;
}
