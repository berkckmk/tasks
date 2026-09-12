import {
  parsePendingAdds,
  parsePendingToggles,
  type PendingAdd,
  type PendingToggle,
} from './widget-contract.ts';

export type WidgetBridgePort = {
  readPendingAdds(): Promise<string>;
  readPendingToggles(): Promise<string>;
  acknowledgePendingAdds(entries: PendingAdd[]): Promise<boolean>;
  acknowledgePendingToggles(entries: PendingToggle[]): Promise<boolean>;
};

/** Implementations must use PendingAdd.id as an idempotency key. */
export type WidgetMutationPort = {
  createFromWidget(userId: string, entry: PendingAdd): Promise<{ itemId: string }>;
  setDoneFromWidget(userId: string, entry: PendingToggle, resolvedItemId?: string): Promise<void>;
};

export type WidgetDrainResult = {
  skipped: boolean;
  addsApplied: number;
  togglesApplied: number;
  failures: number;
};

export class WidgetSyncCoordinator {
  private activeDrain: Promise<WidgetDrainResult> | null = null;
  private readonly bridge: WidgetBridgePort;
  private readonly mutations: WidgetMutationPort;

  constructor(bridge: WidgetBridgePort, mutations: WidgetMutationPort) {
    this.bridge = bridge;
    this.mutations = mutations;
  }

  drain(userId: string | null): Promise<WidgetDrainResult> {
    if (!userId) return Promise.resolve({ skipped: true, addsApplied: 0, togglesApplied: 0, failures: 0 });
    if (this.activeDrain) return this.activeDrain;
    this.activeDrain = this.run(userId).finally(() => {
      this.activeDrain = null;
    });
    return this.activeDrain;
  }

  private async run(userId: string): Promise<WidgetDrainResult> {
    const [rawAdds, rawToggles] = await Promise.all([
      this.bridge.readPendingAdds(),
      this.bridge.readPendingToggles(),
    ]);
    // Parsers reject the whole malformed queue. Nothing is acknowledged from
    // a partial parse, so unreadable user actions remain available to repair.
    const adds = parsePendingAdds(rawAdds);
    const toggles = parsePendingToggles(rawToggles);
    const acknowledgedAdds: PendingAdd[] = [];
    const acknowledgedToggles: PendingToggle[] = [];
    const localToServer = new Map<string, string>();
    let failures = 0;

    // Adds run first. A user can tick the optimistic row before opening the
    // app; its queued toggle still carries the local add:<millis> id.
    for (const add of adds) {
      try {
        const { itemId } = await this.mutations.createFromWidget(userId, add);
        localToServer.set(add.id, itemId);
        acknowledgedAdds.push(add);
      } catch {
        failures += 1;
      }
    }

    for (const toggle of toggles) {
      try {
        await this.mutations.setDoneFromWidget(
          userId,
          toggle,
          localToServer.get(toggle.id),
        );
        acknowledgedToggles.push(toggle);
      } catch {
        failures += 1;
      }
    }

    if (acknowledgedAdds.length) await this.bridge.acknowledgePendingAdds(acknowledgedAdds);
    if (acknowledgedToggles.length) {
      await this.bridge.acknowledgePendingToggles(acknowledgedToggles);
    }
    return {
      skipped: false,
      addsApplied: acknowledgedAdds.length,
      togglesApplied: acknowledgedToggles.length,
      failures,
    };
  }
}
