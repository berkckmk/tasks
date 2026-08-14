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
  await saveTokens(uid, integration, {
    refreshToken: tokens.refresh_token,
    accessToken: tokens.access_token ?? undefined,
    scope,
  });
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
