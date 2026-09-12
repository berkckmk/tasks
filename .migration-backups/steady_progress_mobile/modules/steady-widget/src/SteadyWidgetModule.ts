import { NativeModule, requireOptionalNativeModule } from 'expo';
import type {
  PendingAdd,
  PendingToggle,
  WidgetSnapshot,
} from '../../../src/features/widget/widget-contract';

type WidgetEvents = { onWidgetRoute: () => void };

declare class SteadyWidgetModule extends NativeModule<WidgetEvents> {
  updateWidget(snapshot: WidgetSnapshot): Promise<boolean>;
  clearWidget(): Promise<boolean>;
  readPendingToggles(): Promise<string>;
  readPendingAdds(): Promise<string>;
  clearPendingToggles(ids: string[]): Promise<boolean>;
  clearPendingAdds(ids: string[]): Promise<boolean>;
  acknowledgePendingToggles(entries: PendingToggle[]): Promise<boolean>;
  acknowledgePendingAdds(entries: PendingAdd[]): Promise<boolean>;
  readSnapshot(): Promise<string>;
  takePendingRoute(): Promise<string | null>;
}

// iOS/web have no Android widget. Absence is an explicit unsupported state,
// not a mock implementation which reports successful native writes.
export default requireOptionalNativeModule<SteadyWidgetModule>('SteadyWidget');
