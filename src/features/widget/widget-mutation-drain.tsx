import { useEffect, useMemo } from 'react';
import { AppState } from 'react-native';
import SteadyWidget from '../../../modules/steady-widget';
import { useAppData } from '../../core/data/app-data.tsx';
import { createNativeWidgetCoordinator } from './native-widget-sync.ts';
import { RepositoryWidgetMutations } from './repository-widget-mutations.ts';

/** Drains native widget actions only inside the authenticated production host. */
export function WidgetMutationDrain() {
  const { gateway, userId, synthetic } = useAppData();
  const coordinator = useMemo(
    () => createNativeWidgetCoordinator(new RepositoryWidgetMutations(gateway)),
    [gateway],
  );

  useEffect(() => {
    if (!coordinator) return;
    const drain = () => void coordinator.drain(userId);
    drain();
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') drain();
    });
    const widgetSub = SteadyWidget?.addListener('onWidgetRoute', () => {
      drain();
    });
    return () => {
      subscription.remove();
      widgetSub?.remove();
    };
  }, [coordinator, userId]);

  return null;
}
