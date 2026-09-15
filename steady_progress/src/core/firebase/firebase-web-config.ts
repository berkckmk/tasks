import { getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, type Firestore } from 'firebase/firestore';
import { getFunctions, type Functions } from 'firebase/functions';
import { getMessaging, type Messaging } from 'firebase/messaging';
import { getStorage, type FirebaseStorage } from 'firebase/storage';

export const firebaseWebConfig = {
  apiKey: 'AIzaSyBRQymwI2gg0iiVvP86MNQGWV0HT5rZQvY',
  authDomain: 'tasks-1903.firebaseapp.com',
  projectId: 'tasks-1903',
  storageBucket: 'tasks-1903.firebasestorage.app',
  messagingSenderId: '1012303591315',
  appId: '1:1012303591315:web:4ca9c811a0b6d3465c5a66',
};

let app: FirebaseApp | undefined;

export function getFirebaseWebApp(): FirebaseApp {
  if (!app) {
    const existingApps = getApps();
    app = existingApps.length > 0 ? existingApps[0]! : initializeApp(firebaseWebConfig);
  }
  return app;
}

export function getFirebaseWebAuth(): Auth {
  return getAuth(getFirebaseWebApp());
}

export function getFirebaseWebFirestore(): Firestore {
  return getFirestore(getFirebaseWebApp());
}

export function getFirebaseWebFunctions(): Functions {
  return getFunctions(getFirebaseWebApp());
}

export function getFirebaseWebStorage(): FirebaseStorage {
  return getStorage(getFirebaseWebApp());
}

/**
 * VAPID key for Firebase Cloud Messaging web push.
 * Generate from: Firebase Console → Project Settings → Cloud Messaging → Web Push certificates → Generate key pair
 */
export const FCM_VAPID_KEY: string =
  'BGeU8aHx2H35razksLFVsc1MDmn2XIHAVtdnXAir3BRbIXsJ056KWFWhxAY3d9s8oISZCp82mVJqQxw6d1YrNPU';

export function getFirebaseWebMessaging(): Messaging {
  return getMessaging(getFirebaseWebApp());
}
