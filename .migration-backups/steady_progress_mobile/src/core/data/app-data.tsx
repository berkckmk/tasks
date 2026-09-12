import { createContext, useContext, useMemo, type PropsWithChildren } from 'react';
import type { DataGateway } from './data-gateway.ts';
import { MemoryDataGateway } from './memory-data-gateway.ts';

type AppData = { gateway: DataGateway; userId: string; userEmail?: string; synthetic: boolean };

const AppDataContext = createContext<AppData | null>(null);
const previewUserId = 'preview-user';

function createPreviewGateway(userId: string): DataGateway {
  const gateway = new MemoryDataGateway(userId);
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth();
  const d = now.getDate();

  // Seed Habits
  void gateway.setDocument(`users/${userId}/habits/habit-1`, {
    name: 'Kitap oku (20 sayfa)',
    category: 'personal',
    colorValue: 0xFF86E6B0,
    frequencyLabel: 'Her gün',
    reminderTimeLabel: '07:00',
    createdAt: now,
    updatedAt: now,
  });
  void gateway.setDocument(`users/${userId}/habits/habit-2`, {
    name: 'Günlük su hedefi (2.5L)',
    category: 'health',
    colorValue: 0xFF86E6B0,
    frequencyLabel: 'Her gün',
    createdAt: now,
    updatedAt: now,
  });
  const todayStr = `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  void gateway.setDocument(`users/${userId}/habit_logs/log-water`, {
    habitId: 'habit-2',
    date: todayStr,
    completed: true,
    createdAt: now,
  });
  void gateway.setDocument(`users/${userId}/habits/habit-3`, {
    name: 'Akşam yürüyüşü (30 dk)',
    category: 'fitness',
    colorValue: 0xFF86E6B0,
    frequencyLabel: 'Haftada 5 gün',
    reminderTimeLabel: '19:00',
    createdAt: now,
    updatedAt: now,
  });

  // Seed Tasks
  void gateway.setDocument(`users/${userId}/tasks/task-1`, {
    title: 'Haftalık planlama',
    description: 'Önümüzdeki haftanın önceliklerini belirle',
    category: 'work',
    priority: 'high',
    status: 'todo',
    allDay: false,
    dueDate: new Date(y, m, d, 11, 0),
    createdAt: now,
    updatedAt: now,
  });
  void gateway.setDocument(`users/${userId}/tasks/task-2`, {
    title: 'Instagram kaydedilenler',
    description: 'Kaydedilen gönderileri ayıkla ve not al',
    category: 'personal',
    priority: 'medium',
    status: 'todo',
    allDay: false,
    dueDate: new Date(y, m, d, 11, 30),
    createdAt: now,
    updatedAt: now,
  });
  void gateway.setDocument(`users/${userId}/tasks/task-3`, {
    title: 'Fatura ödemeleri',
    description: 'Elektrik ve internet faturasını öde',
    category: 'finance',
    priority: 'high',
    status: 'todo',
    allDay: false,
    dueDate: new Date(y, m, d, 16, 30),
    createdAt: now,
    updatedAt: now,
  });

  // Seed Reminders
  void gateway.setDocument(`users/${userId}/reminders/rem-1`, {
    title: 'Aubagio 14mg',
    message: 'Günlük ilaç zamanı',
    status: 'pending',
    priority: 'high',
    dueAt: new Date(y, m, d, 9, 0),
    starred: true,
    category: 'Sağlık',
    createdAt: now,
    updatedAt: now,
  });
  void gateway.setDocument(`users/${userId}/reminders/rem-2`, {
    title: 'Doktor randevusu',
    message: 'Genel kontrol muayenesi',
    status: 'pending',
    priority: 'medium',
    dueAt: new Date(y, m, d, 15, 0),
    starred: false,
    category: 'Randevular',
    createdAt: now,
    updatedAt: now,
  });
  void gateway.setDocument(`users/${userId}/reminders/rem-3`, {
    title: 'Akşam ilacı',
    message: 'Yatmadan önce alınacak',
    status: 'pending',
    priority: 'high',
    dueAt: new Date(y, m, d, 21, 30),
    starred: false,
    category: 'Sağlık',
    createdAt: now,
    updatedAt: now,
  });

  return gateway;
}

export function AppDataProvider({ children, gateway, userId = previewUserId, userEmail, synthetic = true }: PropsWithChildren<Partial<AppData>>) {
  const value = useMemo<AppData>(() => ({
    gateway: gateway ?? createPreviewGateway(previewUserId),
    userId,
    userEmail,
    synthetic,
  }), [gateway, synthetic, userEmail, userId]);
  return <AppDataContext.Provider value={value}>{children}</AppDataContext.Provider>;
}

export function useAppData() {
  const value = useContext(AppDataContext);
  if (!value) throw new Error('useAppData must be used inside AppDataProvider');
  return value;
}
