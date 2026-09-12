import SteadyWidget from '../../../modules/steady-widget';
import { WidgetSyncCoordinator, type WidgetMutationPort } from './widget-sync';

export function createNativeWidgetCoordinator(mutations: WidgetMutationPort) {
  return SteadyWidget ? new WidgetSyncCoordinator(SteadyWidget, mutations) : null;
}
