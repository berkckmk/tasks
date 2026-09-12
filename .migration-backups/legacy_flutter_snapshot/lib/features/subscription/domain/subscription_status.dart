import 'package:cloud_firestore/cloud_firestore.dart';

import 'beta_access.dart';

enum SubscriptionState { active, trialing, expired, canceled }

/// Mirrors `users/{uid}/subscription/status`. This is the single source of
/// truth for what plan a user has and what a future billing provider
/// (Stripe/RevenueCat/Play Billing/Lemon Squeezy/Paddle) would keep in sync
/// via webhooks.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.planId,
    required this.status,
    required this.startedAt,
    this.expiresAt,
    required this.billingProvider,
    required this.isTrialActive,
    this.trialEndsAt,
  });

  final String planId;
  final SubscriptionState status;
  final DateTime startedAt;
  final DateTime? expiresAt;

  /// 'none' until a real provider is wired up, then e.g. 'stripe',
  /// 'revenuecat', 'play_billing', 'lemon_squeezy', 'paddle'.
  final String billingProvider;
  final bool isTrialActive;
  final DateTime? trialEndsAt;

  factory SubscriptionStatus.fromFirestore(Map<String, dynamic> data) {
    return SubscriptionStatus(
      planId: data['planId'] as String? ?? 'starter',
      status: SubscriptionState.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SubscriptionState.active,
      ),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      billingProvider: data['billingProvider'] as String? ?? 'none',
      isTrialActive: data['isTrialActive'] as bool? ?? false,
      trialEndsAt: (data['trialEndsAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Whether this subscription still entitles the user to [planId] right
  /// now. `expired`/`canceled` never entitle, and an `active` subscription
  /// stops entitling once [expiresAt] has passed — a webhook that never
  /// arrived (failed delivery, a Play purchase refunded out-of-band) must
  /// not leave a paid plan granted forever.
  bool isEntitledAt(DateTime now) {
    switch (status) {
      case SubscriptionState.expired:
      case SubscriptionState.canceled:
        return false;
      case SubscriptionState.trialing:
        final trialEnd = trialEndsAt;
        if (trialEnd != null && !now.isBefore(trialEnd)) return false;
      case SubscriptionState.active:
        break;
    }
    final expiry = expiresAt;
    return expiry == null || now.isBefore(expiry);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'planId': planId,
      'status': status.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'billingProvider': billingProvider,
      'isTrialActive': isTrialActive,
      'trialEndsAt': trialEndsAt == null ? null : Timestamp.fromDate(trialEndsAt!),
    };
  }
}

/// The plan the app should actually behave as, given a (possibly absent)
/// subscription document.
///
/// Falls back to `starter` for a missing document or a lapsed subscription,
/// so a still-loading stream or a webhook that never landed can never
/// silently unlock a paid module. While [kBetaAllAccess] is on this returns
/// [kBetaPlanId] for everyone — see `beta_access.dart` for why and for how
/// to turn it off.
String resolveActivePlanId(SubscriptionStatus? status, {DateTime? now}) {
  if (kBetaAllAccess) return kBetaPlanId;
  if (status == null) return 'starter';
  if (!status.isEntitledAt(now ?? DateTime.now())) return 'starter';
  return status.planId;
}
