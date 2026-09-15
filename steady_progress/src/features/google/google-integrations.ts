import { Platform } from 'react-native';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { dateFromFirestore } from '../../core/data/firestore-values.ts';

export const googleIntegrationIds = ['calendar', 'sheets', 'drive', 'docs'] as const;
export type GoogleIntegrationId = typeof googleIntegrationIds[number];
export type GoogleIntegrationStatus = {
  id: GoogleIntegrationId;
  enabled: boolean;
  status: 'notConnected' | 'connected' | 'syncing' | 'error';
  lastSyncedAt: Date | null;
  errorMessage: string | null;
};

const webClientId = '1012303591315-95nekgj63ffhc26sbrjrt3sm3i48pm0r.apps.googleusercontent.com';
const definitions: Record<GoogleIntegrationId, { docId: string; scope: string }> = {
  calendar: { docId: 'google_calendar', scope: 'https://www.googleapis.com/auth/calendar.events' },
  sheets: { docId: 'google_sheets', scope: 'https://www.googleapis.com/auth/spreadsheets' },
  drive: { docId: 'google_drive', scope: 'https://www.googleapis.com/auth/drive.file' },
  docs: { docId: 'google_docs', scope: 'https://www.googleapis.com/auth/documents' },
};

function integrationFromDocument(id: GoogleIntegrationId, data: Record<string, unknown>): GoogleIntegrationStatus {
  const status = data.status;
  return {
    id,
    enabled: data.enabled === true,
    status: status === 'connected' || status === 'syncing' || status === 'error' ? status : 'notConnected',
    lastSyncedAt: dateFromFirestore(data.lastSyncedAt ?? data.lastExportedAt ?? data.lastBackupAt ?? data.lastReportGeneratedAt),
    errorMessage: typeof data.errorMessage === 'string' ? data.errorMessage : null,
  };
}

export class GoogleIntegrationsRepository {
  constructor(private readonly gateway: DataGateway, private readonly userId: string) {}
  watch(onData: (statuses: GoogleIntegrationStatus[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(`users/${this.userId}/integrations`, {}, (rows) => {
      onData(googleIntegrationIds.map((id) => {
        const row = rows.find((item) => item.id === definitions[id].docId);
        return integrationFromDocument(id, row?.data ?? {});
      }));
    }, onError);
  }
  async connect(id: GoogleIntegrationId) {
    if (Platform.OS === 'web') {
      throw new Error('Google servis entegrasyonu web sürümünde yakında aktif olacaktır. Lütfen mobil uygulamayı kullanın.');
    }
    const scope = definitions[id].scope;
    GoogleSignin.configure({ webClientId, offlineAccess: true, forceCodeForRefreshToken: true, scopes: [scope] });
    await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
    const response = await GoogleSignin.signIn();
    if (response.type !== 'success') throw new Error('Google izin isteği iptal edildi.');
    const authCode = response.data.serverAuthCode;
    if (!authCode) throw new Error('Google tek kullanımlık yetkilendirme kodu döndürmedi.');
    await this.gateway.callFunction('connectGoogleIntegration', { integration: id, authCode });
  }
  disconnect(id: GoogleIntegrationId) { return this.gateway.callFunction('disconnectGoogleIntegration', { integration: id }); }
  syncCalendar() { return this.gateway.callFunction('syncGoogleCalendar', {}); }
  exportSheets() { return this.gateway.callFunction('exportToGoogleSheets', { modules: ['Habits', 'Habit Logs', 'Tasks', 'Goals', 'Finance', 'Workouts', 'Learning', 'Content'] }); }
  backupDrive() { return this.gateway.callFunction('backupToGoogleDrive', {}); }
  generateDocsReport() { const end = new Date(); const start = new Date(end.getFullYear(), end.getMonth(), 1); return this.gateway.callFunction('generateGoogleDocsReport', { type: 'monthly', periodStart: start.toISOString(), periodEnd: end.toISOString() }); }
}
