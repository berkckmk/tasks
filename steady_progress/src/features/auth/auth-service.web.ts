import { updateEmail, updateProfile } from 'firebase/auth';
import { getFirebaseWebAuth } from '../../core/firebase/firebase-web-config';

export async function updateAuthIdentity(displayName: string, email: string): Promise<void> {
  const current = getFirebaseWebAuth().currentUser;
  if (!current) throw new Error('Oturum bulunamadı.');
  if (current.displayName !== displayName) {
    await updateProfile(current, { displayName });
  }
  if (email && current.email !== email) {
    await updateEmail(current, email);
  }
}

export function getCurrentAuthUser(): { displayName: string | null; email: string | null; photoURL: string | null } | null {
  const current = getFirebaseWebAuth().currentUser;
  if (!current) return null;
  return {
    displayName: current.displayName,
    email: current.email,
    photoURL: current.photoURL,
  };
}
