import { useCallback, useEffect, useState } from 'react';
import { router, type Href } from 'expo-router';
import { AppState } from 'react-native';
import SteadyWidget from '../../modules/steady-widget';
import { AppButton, AppCard, AppScreen, AppText } from '@/components/ui';
import {
  parsePendingAdds,
  parsePendingToggles,
  parseWidgetRoute,
  previewSnapshot,
} from '@/features/widget/widget-contract';

export function WidgetPreviewScreen() {
  const [status, setStatus] = useState('Bağlantı bekleniyor');
  const [details, setDetails] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const read = useCallback(async () => {
    if (!SteadyWidget) {
      setStatus('Android widget testi bu platformda kullanılamıyor');
      return;
    }
    try {
      const [snapshot, adds, toggles] = await Promise.all([
        SteadyWidget.readSnapshot(),
        SteadyWidget.readPendingAdds(),
        SteadyWidget.readPendingToggles(),
      ]);
      const pendingAdds = parsePendingAdds(adds);
      const pendingToggles = parsePendingToggles(toggles);
      setDetails(JSON.stringify({ snapshot: JSON.parse(snapshot), pendingAdds, pendingToggles }, null, 2));
      setStatus(`Köprü bağlı · ${pendingAdds.length} ekleme · ${pendingToggles.length} tamamlama bekliyor`);
      setError(null);
    } catch (reason) {
      setError(String(reason));
    }
  }, []);

  useEffect(() => {
    void read();
    const appState = AppState.addEventListener('change', (state) => {
      if (state === 'active') void read();
    });
    return () => appState.remove();
  }, [read]);

  async function seed() {
    if (!SteadyWidget || busy) return;
    setBusy(true);
    try {
      await SteadyWidget.updateWidget(previewSnapshot);
      await read();
    } catch (reason) {
      setError(String(reason));
    } finally {
      setBusy(false);
    }
  }

  return (
    <AppScreen>
      <AppText variant="h3">Android widget prototipi</AppText>
      <AppText tone="muted">
        Mevcut Kotlin/XML widget ile yeni ortak uygulamanın bağlantı denemesi. Bu ayrı önizleme
        uygulaması gerçek hesabına bağlanmaz.
      </AppText>
      <AppCard>
        <AppText accessibilityLiveRegion="polite" variant="title">{status}</AppText>
        <AppText tone="muted">
          Ana ekrandan Steady Progress Preview uygulamasının Today widget’ını ekle. Örnek veriyi
          gönder; widget’ta tamamlama ve “+” işlemlerini dene, sonra bu ekrana dön.
        </AppText>
      </AppCard>
      <AppButton
        disabled={!SteadyWidget || busy}
        onPress={() => void seed()}
        label={busy ? 'Gönderiliyor…' : 'Örnek veriyi widget’a gönder'}
        loading={busy}
        expand
      />
      <AppButton
        onPress={() => router.push('/ui-standards')}
        label="Ortak UI standardını aç"
        variant="text"
        expand
      />
      <AppButton onPress={() => router.push('/tasks')} label="Tasks ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/habits')} label="Habits ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/learning')} label="Learning ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/reminders')} label="Reminders ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/content')} label="Content ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/workout')} label="Workout ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/goals')} label="Goals ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/analytics')} label="Analytics ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/reports')} label="Reports ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/dashboard')} label="Today ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/finance')} label="Finance ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/notifications')} label="Bildirim ayarlarını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/profile')} label="Profile ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/more')} label="More ekranını aç" variant="text" expand />
      <AppButton onPress={() => router.push('/main')} label="Production sekmelerini aç" variant="text" expand />
      <AppButton
        disabled={!SteadyWidget || busy}
        onPress={() => void read()}
        label="Widget verisini ve bekleyen işlemleri oku"
        variant="secondary"
        expand
      />
      <AppText tone="muted">
        Bekleyen işlemler bu prototipte silinmez veya buluta yazılmaz. İşlem varsa örnek veriyle
        üzerine yazma engellenir. Editörler sonraki aşamada taşınacak.
      </AppText>
      {error ? <AppText selectable accessibilityRole="alert" variant="bodySmall" tone="error">{error}</AppText> : null}
      {details !== '' ? <AppText selectable variant="meta">{details}</AppText> : null}
    </AppScreen>
  );
}

/** Kept above the route stack so warm intents work even on the target page. */
export function WidgetRouteListener() {
  useEffect(() => {
    if (!SteadyWidget) return;
    let active = true;
    async function consume() {
      try {
        const route = parseWidgetRoute(await SteadyWidget!.takePendingRoute());
        if (active && route) router.push(route as Href);
      } catch (reason) {
        console.warn('Widget route could not be read', reason);
      }
    }
    const subscription = SteadyWidget.addListener('onWidgetRoute', () => void consume());
    void consume();
    return () => {
      active = false;
      subscription.remove();
    };
  }, []);
  return null;
}
