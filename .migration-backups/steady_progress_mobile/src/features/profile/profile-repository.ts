import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts'; import { userProfileFromDocument, type UserProfile } from './user-profile.ts';
const VIP_OWNER_EMAIL = 'ekmekarasitutun@gmail.com';

export class ProfileRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watch(onData: (profile: UserProfile | null) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchDocument(`users/${this.userId}`, (row) => {
      if (!row) {
        onData(null);
        return;
      }
      const profile = userProfileFromDocument(row.id, row.data);
      if (profile.email.toLowerCase() === VIP_OWNER_EMAIL && profile.selectedPlan !== 'complete') {
        profile.selectedPlan = 'complete';
        void this.gateway.setDocument(`users/${this.userId}`, { selectedPlan: 'complete', updatedAt: this.gateway.serverTimestamp() }, { merge: true });
      }
      onData(profile);
    }, onError);
  }

  saveIdentity(input: { displayName: string; email: string }) {
    const isVip = input.email.trim().toLowerCase() === VIP_OWNER_EMAIL;
    return this.gateway.setDocument(`users/${this.userId}`, {
      uid: this.userId,
      displayName: input.displayName,
      email: input.email,
      ...(isVip ? { selectedPlan: 'complete' } : {}),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      updatedAt: this.gateway.serverTimestamp(),
    }, { merge: true });
  }

  createInitialProfile(input: { displayName: string; email: string }) {
    const isVip = input.email.trim().toLowerCase() === VIP_OWNER_EMAIL;
    return this.gateway.setDocument(`users/${this.userId}`, {
      uid: this.userId,
      displayName: input.displayName,
      email: input.email,
      selectedPlan: isVip ? 'complete' : 'starter',
      onboardingCompleted: false,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      appPreferences: { notificationsEnabled: true, theme: 'system' },
      linkedProviders: ['password'],
      createdAt: this.gateway.serverTimestamp(),
      updatedAt: this.gateway.serverTimestamp(),
    });
  }

  markOnboardingCompleted() {
    return this.gateway.setDocument(`users/${this.userId}`, { onboardingCompleted: true, updatedAt: this.gateway.serverTimestamp() }, { merge: true });
  }

  updatePhotoUrl(photoUrl: string) {
    return this.gateway.setDocument(`users/${this.userId}`, { photoUrl, updatedAt: this.gateway.serverTimestamp() }, { merge: true });
  }
}
