/// Closed-beta switch: while true, every signed-in account is treated as
/// being on the `complete` plan regardless of what
/// `users/{uid}/subscription/status` says.
///
/// This exists because the app is currently used only by the developer and a
/// handful of invited testers, and no real payment provider is connected
/// yet. Rather than leaving `subscription/status` client-writable (which is
/// what previously made every server-side plan check bypassable — the
/// document that guards access was writable by the account being guarded),
/// the doc is now Admin-SDK-only and free access is granted by this explicit,
/// auditable flag instead.
///
/// ## Turning the beta off
///
/// The flag is mirrored in three places that must be flipped together, since
/// each enforcement layer has to decide independently and none of them can
/// read the others:
///
///  1. this constant  (Flutter client — what the UI unlocks)
///  2. `BETA_ALL_ACCESS` in `functions/src/lib/plan.ts`  (Cloud Functions)
///  3. `betaAllAccess()` in `firestore.rules`  (direct Firestore access)
///
/// Flipping only some of them fails safe in the sense that the *strictest*
/// layer wins, but it produces confusing behaviour (UI offers a feature the
/// rules then reject), so change all three in one commit.
///
/// Everything needed for real billing is already wired and stays wired while
/// this is true: `StripeCheckoutService`, `PlayBillingService`, the
/// `handleBillingWebhook` / `verifyPlayPurchase` functions, and the
/// expiry-aware plan resolution in [resolveActivePlanId]. Going live is:
/// flip these three flags, fill in the real price/product IDs in
/// `billing_product_ids.dart`, and point `billingServiceProvider` at the
/// real services (see the comment there).
const bool kBetaAllAccess = true;

/// The plan every account gets while [kBetaAllAccess] is on.
const String kBetaPlanId = 'complete';
