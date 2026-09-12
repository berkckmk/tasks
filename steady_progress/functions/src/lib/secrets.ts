import { defineSecret } from "firebase-functions/params";

/**
 * Secret Manager bindings for the three values that must never be readable
 * from the function's configuration.
 *
 * These were previously plain `process.env` reads with no `secrets:`
 * declaration on any function. That combination is worse than it looks:
 *
 *  - Values set with `firebase functions:secrets:set` are only injected into
 *    functions that *declare* them, so without a binding the secret was
 *    never actually available and every dependent function failed at
 *    runtime — while `.env.example` told you to set them that way.
 *  - The workaround (putting them in `.env`) deploys them as plaintext
 *    function environment variables, visible to anyone with `roles/viewer`
 *    via `gcloud functions describe`.
 *
 * Set them with:
 *   firebase functions:secrets:set STRIPE_SECRET_KEY
 *   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
 *   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_SECRET
 *
 * Non-secret configuration (client IDs, price IDs, package name, allowed
 * origins) stays in `.env` — see functions/.env.example.
 */
export const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
export const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
export const googleOAuthClientSecret = defineSecret("GOOGLE_OAUTH_CLIENT_SECRET");

/** Every secret the Google integration functions need. */
export const googleSecrets = [googleOAuthClientSecret];

/** Every secret the Stripe billing functions need. */
export const stripeSecrets = [stripeSecretKey, stripeWebhookSecret];
