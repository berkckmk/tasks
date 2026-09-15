import {
  GoogleAuthProvider,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  reload,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  updateProfile,
  type User,
} from 'firebase/auth';
import { useEffect, useMemo, useRef, useState, type PropsWithChildren } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, AppTextField, Kicker } from '@/components/ui';
import { AppDataProvider } from '@/core/data/app-data';
import { FirebaseDataGateway } from '@/core/data/firebase-data-gateway.web';
import { getFirebaseWebAuth } from '@/core/firebase/firebase-web-config';
import { ProfileRepository } from '@/features/profile/profile-repository';
import { SubscriptionRepository } from '@/features/subscription/subscription-repository';
import { OnboardingScreen } from '@/screens/onboarding-screen';
import { colors, spacing } from '@/theme';

export async function signOutApp() {
  await signOut(getFirebaseWebAuth());
}

export function ProductionDataHost({ children }: PropsWithChildren) {
  const gateway = useMemo(() => new FirebaseDataGateway(), []);
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileReady, setProfileReady] = useState(false);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [profileAttempt, setProfileAttempt] = useState(0);
  const [onboardingCompleted, setOnboardingCompleted] = useState(false);
  const tokenOwner = useRef<string | null>(null);

  useEffect(() => {
    const auth = getFirebaseWebAuth();
    return onAuthStateChanged(auth, (next) => {
      tokenOwner.current = next?.uid ?? null;
      setUser(next);
      setLoading(false);
    });
  }, [gateway]);

  useEffect(() => {
    setProfileReady(false);
    setProfileError(null);
    setOnboardingCompleted(false);
    if (!user?.emailVerified) return;
    const repository = new ProfileRepository(gateway, user.uid);
    let creating = false;
    let active = true;
    const timeout = setTimeout(() => {
      if (active) setProfileError('Profil yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.');
    }, 45000);
    const fail = (reason: unknown) => {
      if (!active) return;
      clearTimeout(timeout);
      setProfileError(authError(reason));
      setProfileReady(false);
    };
    const stop = repository.watch((profile) => {
      if (!active) return;
      if (!profile && !creating) {
        creating = true;
        void repository
          .createInitialProfile({ displayName: user.displayName ?? '', email: user.email ?? '' })
          .catch(fail);
        // Subscription initialization is independent of profile readiness.
        void gateway
          .getDocument(`users/${user.uid}/subscription/status`)
          .then((status) => {
            if (!status && active) {
              return new SubscriptionRepository(gateway, user.uid, user.email).createInitialStatus();
            }
          })
          .catch(() => undefined);
        return;
      }
      if (profile) {
        clearTimeout(timeout);
        setProfileError(null);
        setOnboardingCompleted(profile.onboardingCompleted);
        setProfileReady(true);
      }
    }, fail);
    return () => {
      active = false;
      clearTimeout(timeout);
      stop();
    };
  }, [gateway, user, profileAttempt]);

  if (loading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background }}>
        <ActivityIndicator color={colors.text} />
      </View>
    );
  }

  if (!user) return <AuthScreen gateway={gateway} />;
  if (!user.emailVerified) return <VerifyEmailScreen user={user} onVerified={setUser} />;
  if (profileError) {
    return (
      <AppScreen contentStyle={{ flexGrow: 1, justifyContent: 'center' }}>
        <AppCard>
          <AppText variant="h3">Profil yüklenemedi</AppText>
          <AppText tone="error" accessibilityRole="alert">{profileError}</AppText>
          <AppButton label="Tekrar dene" onPress={() => setProfileAttempt((attempt) => attempt + 1)} />
          <AppButton label="Çıkış yap" variant="text" onPress={() => void signOutApp()} />
        </AppCard>
      </AppScreen>
    );
  }

  return (
    <AppDataProvider gateway={gateway} userId={user.uid} userEmail={user.email ?? ''} synthetic={false}>
      {profileReady ? (
        onboardingCompleted ? (
          children
        ) : (
          <OnboardingScreen onCompleted={() => setOnboardingCompleted(true)} />
        )
      ) : (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background }}>
          <ActivityIndicator color={colors.text} />
        </View>
      )}
    </AppDataProvider>
  );
}

function AuthScreen({ gateway: _ }: { gateway: FirebaseDataGateway }) {
  const [register, setRegister] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [googleBusy, setGoogleBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (!email.trim() || !password) {
      setError('E-posta ve parola gerekli.');
      return;
    }
    if (register && !name.trim()) {
      setError('Görünen ad gerekli.');
      return;
    }
    setBusy(true);
    try {
      const auth = getFirebaseWebAuth();
      if (register) {
        const credential = await createUserWithEmailAndPassword(auth, email.trim(), password);
        await updateProfile(credential.user, { displayName: name.trim() });
        await sendEmailVerification(credential.user);
      } else {
        await signInWithEmailAndPassword(auth, email.trim(), password);
      }
      setError(null);
    } catch (reason) {
      setError(authError(reason));
    } finally {
      setBusy(false);
    }
  }

  async function continueWithGoogle() {
    setGoogleBusy(true);
    setError(null);
    try {
      const auth = getFirebaseWebAuth();
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });
      await signInWithPopup(auth, provider);
    } catch (reason: unknown) {
      const err = reason as { code?: string };
      if (err?.code === 'auth/popup-closed-by-user' || err?.code === 'auth/cancelled-popup-request') return;
      setError(authError(reason));
    } finally {
      setGoogleBusy(false);
    }
  }

  async function resetPassword() {
    if (!email.trim()) {
      setError('Önce e-posta adresini gir.');
      return;
    }
    try {
      await sendPasswordResetEmail(getFirebaseWebAuth(), email.trim());
      setError('Parola yenileme bağlantısı gönderildi.');
    } catch (reason) {
      setError(authError(reason));
    }
  }

  return (
    <AppScreen contentStyle={{ flexGrow: 1, justifyContent: 'center' }}>
      <Kicker>Steady Progress</Kicker>
      <AppText variant="h3">{register ? 'Hesap oluştur' : 'Giriş yap'}</AppText>
      <AppCard>
        {register ? <AppTextField label="Görünen ad" value={name} onChangeText={setName} autoComplete="name" /> : null}
        <AppTextField
          label="E-posta"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
          autoComplete="email"
        />
        <AppTextField
          label="Parola"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          autoComplete={register ? 'new-password' : 'current-password'}
        />
        {error ? (
          <AppText accessibilityRole="alert" tone={error.includes('gönderildi') ? 'muted' : 'error'}>
            {error}
          </AppText>
        ) : null}
        <AppButton label={register ? 'Kayıt ol' : 'Giriş yap'} loading={busy} disabled={busy || googleBusy} onPress={() => void submit()} />
        <AppButton
          label={register ? 'Zaten hesabım var' : 'Yeni hesap oluştur'}
          variant="text"
          disabled={busy || googleBusy}
          onPress={() => {
            setRegister((value) => !value);
            setError(null);
          }}
        />
        {!register ? (
          <AppButton label="Parolamı unuttum" variant="text" disabled={busy || googleBusy} onPress={() => void resetPassword()} />
        ) : null}
        <View style={{ flexDirection: 'row', alignItems: 'center', marginVertical: spacing.xs }}>
          <View style={{ flex: 1, height: StyleSheet.hairlineWidth, backgroundColor: colors.divider }} />
          <AppText tone="muted" style={{ marginHorizontal: spacing.sm }}>
            veya
          </AppText>
          <View style={{ flex: 1, height: StyleSheet.hairlineWidth, backgroundColor: colors.divider }} />
        </View>
        <AppButton
          label={googleBusy ? 'Lütfen bekleyin...' : 'Google ile devam et'}
          variant="secondary"
          icon={<AppIcon name="googleLogo" size={20} />}
          loading={googleBusy}
          disabled={busy || googleBusy}
          onPress={() => void continueWithGoogle()}
        />
      </AppCard>
    </AppScreen>
  );
}

function VerifyEmailScreen({ user, onVerified }: { user: User; onVerified: (user: User) => void }) {
  const [message, setMessage] = useState(
    `${user.email ?? 'E-postana'} bir doğrulama bağlantısı gönderdik. Lütfen gelen kutunu ve spam klasörünü kontrol et.`,
  );
  const [busy, setBusy] = useState(false);
  const [resending, setResending] = useState(false);

  async function refresh() {
    setBusy(true);
    try {
      await reload(user);
      const auth = getFirebaseWebAuth();
      const current = auth.currentUser;
      if (current?.emailVerified) {
        await current.getIdToken(true);
        onVerified(current);
      } else {
        setMessage('E-posta henüz doğrulanmadı. Bağlantıyı açtıktan sonra tekrar dene.');
      }
    } catch (e) {
      setMessage('Doğrulama kontrol edilirken bir sorun oluştu: ' + authError(e));
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    setResending(true);
    try {
      await sendEmailVerification(user);
      setMessage(`Doğrulama bağlantısı ${user.email ?? ''} adresine tekrar gönderildi. Lütfen gelen kutusu ve spam klasörünü kontrol et.`);
    } catch (e) {
      setMessage('Bağlantı gönderilemedi: ' + authError(e));
    } finally {
      setResending(false);
    }
  }

  return (
    <AppScreen contentStyle={{ flexGrow: 1, justifyContent: 'center' }}>
      <AppCard>
        <AppText variant="h3">E-postanı doğrula</AppText>
        <AppText tone="muted">{message}</AppText>
        <AppButton label="Doğruladım" loading={busy} disabled={busy || resending} onPress={() => void refresh()} />
        <AppButton label="Bağlantıyı tekrar gönder" variant="secondary" loading={resending} disabled={busy || resending} onPress={() => void resend()} />
        <AppButton label="Çıkış yap" variant="text" disabled={busy || resending} onPress={() => void signOutApp()} />
      </AppCard>
    </AppScreen>
  );
}

function authError(reason: unknown) {
  const code = reason && typeof reason === 'object' && 'code' in reason ? String(reason.code) : '';
  if (code.includes('invalid-credential')) return 'E-posta veya parola hatalı.';
  if (code.includes('email-already-in-use')) return 'Bu e-posta zaten kullanımda.';
  if (code.includes('account-exists-with-different-credential')) return 'Bu e-posta başka bir yöntemle kayıtlı. Parolanızla giriş yapın.';
  if (code.includes('weak-password')) return 'Parola en az 6 karakter olmalı.';
  if (code.includes('network-request-failed')) return 'Ağ bağlantısı kurulamadı.';
  if (code.includes('play-services-not-available')) return 'Google Play Hizmetleri kullanılamıyor.';
  if (code.includes('too-many-requests')) return 'Çok fazla istek yapıldı. Lütfen biraz bekleyin.';
  return String(reason);
}
