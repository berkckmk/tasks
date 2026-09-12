import { dateFromFirestore } from '../../core/data/firestore-values.ts';

export type SubscriptionState = 'active' | 'trialing' | 'expired' | 'canceled';
export type SubscriptionStatus = {
  planId: string;
  status: SubscriptionState;
  startedAt: Date | null;
  expiresAt: Date | null;
  billingProvider: string;
  isTrialActive: boolean;
  trialEndsAt: Date | null;
};

export function subscriptionStatusFromDocument(data: Record<string, unknown>): SubscriptionStatus {
  const state = data.status;
  return {
    planId: typeof data.planId === 'string' ? data.planId : 'starter',
    status: state === 'trialing' || state === 'expired' || state === 'canceled' ? state : 'active',
    startedAt: dateFromFirestore(data.startedAt),
    expiresAt: dateFromFirestore(data.expiresAt),
    billingProvider: typeof data.billingProvider === 'string' ? data.billingProvider : 'none',
    isTrialActive: data.isTrialActive === true,
    trialEndsAt: dateFromFirestore(data.trialEndsAt),
  };
}

export function isSubscriptionEntitled(status: SubscriptionStatus, now = new Date()) {
  if (status.status === 'expired' || status.status === 'canceled') return false;
  if (status.status === 'trialing' && status.trialEndsAt && now >= status.trialEndsAt) return false;
  return !status.expiresAt || now < status.expiresAt;
}
