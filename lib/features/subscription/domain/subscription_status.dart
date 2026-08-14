import 'package:cloud_firestore/cloud_firestore.dart';

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
