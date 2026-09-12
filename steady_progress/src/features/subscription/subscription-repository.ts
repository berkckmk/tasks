import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { subscriptionStatusFromDocument, type SubscriptionStatus } from './subscription-status.ts';

const VIP_OWNER_EMAIL = 'ekmekarasitutun@gmail.com';
const VIP_DAYS = 999;

export class SubscriptionRepository {
  constructor(
    private readonly gateway: DataGateway,
    private readonly userId: string,
    private readonly userEmail?: string | null,
  ) {}

  private isVipEmail(email?: string | null): boolean {
    return email?.trim().toLowerCase() === VIP_OWNER_EMAIL;
  }

  private getVipStatus(): SubscriptionStatus {
    const started = new Date();
    const expires = new Date(started.getTime() + VIP_DAYS * 24 * 60 * 60 * 1000);
    return {
      planId: 'complete',
      status: 'active',
      startedAt: started,
      expiresAt: expires,
      billingProvider: 'owner_grant',
      isTrialActive: false,
      trialEndsAt: null,
    };
  }

  watch(onData: (status: SubscriptionStatus | null) => void, onError: (error: unknown) => void): Unsubscribe {
    if (this.isVipEmail(this.userEmail)) {
      onData(this.getVipStatus());
      return () => undefined;
    }

    return this.gateway.watchDocument(`users/${this.userId}/subscription/status`, async (row) => {
      try {
        const profile = await this.gateway.getDocument(`users/${this.userId}`);
        if (profile && this.isVipEmail(profile.data.email as string)) {
          onData(this.getVipStatus());
          return;
        }
      } catch {
        // ignore profile lookup failure
      }
      onData(row ? subscriptionStatusFromDocument(row.data) : null);
    }, onError);
  }

  createInitialStatus() {
    if (this.isVipEmail(this.userEmail)) {
      const expires = new Date(Date.now() + VIP_DAYS * 24 * 60 * 60 * 1000);
      return this.gateway.setDocument(`users/${this.userId}/subscription/status`, {
        planId: 'complete', status: 'active', startedAt: this.gateway.serverTimestamp(),
        expiresAt: expires, billingProvider: 'owner_grant', isTrialActive: false, trialEndsAt: null,
      });
    }
    return this.gateway.setDocument(`users/${this.userId}/subscription/status`, {
      planId: 'starter', status: 'active', startedAt: this.gateway.serverTimestamp(),
      expiresAt: null, billingProvider: 'none', isTrialActive: false, trialEndsAt: null,
    });
  }
}
