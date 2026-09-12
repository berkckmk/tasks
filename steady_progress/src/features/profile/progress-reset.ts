import type { DataGateway } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';

export type ProgressAreaId =
  | 'habits'
  | 'tasks'
  | 'reminders'
  | 'goals'
  | 'content'
  | 'workout'
  | 'finance'
  | 'learning';

export type ProgressAreaOption = {
  id: ProgressAreaId;
  label: string;
  description: string;
};

export const PROGRESS_AREAS: ProgressAreaOption[] = [
  { id: 'habits', label: 'Alışkanlıklar', description: 'Günlük ve geçmiş tamamlama logları temizlenir' },
  { id: 'tasks', label: 'Görevler', description: 'Tamamlanan görevler yapılacak durumuna döner' },
  { id: 'reminders', label: 'Hatırlatıcılar', description: 'Tamamlanan hatırlatıcılar aktif duruma döner' },
  { id: 'goals', label: 'Hedefler', description: 'İlerleme oranları ve kilometre taşları sıfırlanır' },
  { id: 'content', label: 'İçerik Planlayıcı', description: 'İçerik durumları fikir aşamasına döner' },
  { id: 'workout', label: 'Antrenman', description: 'Egzersiz ve antrenman geçmişi temizlenir' },
  { id: 'finance', label: 'Finans', description: 'İşlem kayıtları temizlenir, birikim sıfırlanır' },
  { id: 'learning', label: 'Öğrenme', description: 'Okuma ve ders ilerleme durumları sıfırlanır' },
];

export async function resetProgressForAreas(
  gateway: DataGateway,
  userId: string,
  areas: ProgressAreaId[],
): Promise<void> {
  const operations: Promise<void>[] = [];

  if (areas.includes('habits')) {
    operations.push((async () => {
      const logs = await gateway.getCollection(userCollection(userId, 'habit_logs'), { limit: 500 });
      if (logs.length > 0) {
        await gateway.deleteDocuments(logs.map((l) => `${userCollection(userId, 'habit_logs')}/${l.id}`));
      }
    })());
  }

  if (areas.includes('tasks')) {
    operations.push((async () => {
      const tasks = await gateway.getCollection(userCollection(userId, 'tasks'), { limit: 500 });
      for (const t of tasks) {
        if (t.data.status === 'done' || t.data.status === 'inProgress') {
          await gateway.updateDocument(`${userCollection(userId, 'tasks')}/${t.id}`, {
            status: 'todo',
            updatedAt: gateway.serverTimestamp(),
          });
        }
      }
    })());
  }

  if (areas.includes('reminders')) {
    operations.push((async () => {
      const reminders = await gateway.getCollection(userCollection(userId, 'reminders'), { limit: 500 });
      for (const r of reminders) {
        if (r.data.status === 'completed') {
          await gateway.updateDocument(`${userCollection(userId, 'reminders')}/${r.id}`, {
            status: 'scheduled',
            notifiedAt: gateway.deleteField(),
            updatedAt: gateway.serverTimestamp(),
          });
        }
      }
    })());
  }

  if (areas.includes('goals')) {
    operations.push((async () => {
      const goals = await gateway.getCollection(userCollection(userId, 'goals'), { limit: 500 });
      for (const g of goals) {
        const milestones = Array.isArray(g.data.milestones)
          ? (g.data.milestones as Record<string, unknown>[]).map((m) => ({ ...m, completed: false }))
          : [];
        await gateway.updateDocument(`${userCollection(userId, 'goals')}/${g.id}`, {
          manualProgress: 0,
          milestones,
          updatedAt: gateway.serverTimestamp(),
        });
      }
    })());
  }

  if (areas.includes('content')) {
    operations.push((async () => {
      const items = await gateway.getCollection(userCollection(userId, 'content_items'), { limit: 500 });
      for (const item of items) {
        if (item.data.status !== 'idea') {
          await gateway.updateDocument(`${userCollection(userId, 'content_items')}/${item.id}`, {
            status: 'idea',
            updatedAt: gateway.serverTimestamp(),
          });
        }
      }
    })());
  }

  if (areas.includes('workout')) {
    operations.push((async () => {
      const logs = await gateway.getCollection(userCollection(userId, 'exercise_logs'), { limit: 500 });
      if (logs.length > 0) {
        await gateway.deleteDocuments(logs.map((l) => `${userCollection(userId, 'exercise_logs')}/${l.id}`));
      }
      const workouts = await gateway.getCollection(userCollection(userId, 'workouts'), { limit: 500 });
      if (workouts.length > 0) {
        await gateway.deleteDocuments(workouts.map((w) => `${userCollection(userId, 'workouts')}/${w.id}`));
      }
    })());
  }

  if (areas.includes('finance')) {
    operations.push((async () => {
      const transactions = await gateway.getCollection(userCollection(userId, 'finance_transactions'), { limit: 500 });
      if (transactions.length > 0) {
        await gateway.deleteDocuments(transactions.map((t) => `${userCollection(userId, 'finance_transactions')}/${t.id}`));
      }
      const goals = await gateway.getCollection(userCollection(userId, 'savings_goals'), { limit: 500 });
      for (const g of goals) {
        await gateway.updateDocument(`${userCollection(userId, 'savings_goals')}/${g.id}`, {
          currentAmount: 0,
        });
      }
    })());
  }

  if (areas.includes('learning')) {
    operations.push((async () => {
      const items = await gateway.getCollection(userCollection(userId, 'learning_items'), { limit: 500 });
      for (const item of items) {
        if (item.data.status !== 'notStarted') {
          await gateway.updateDocument(`${userCollection(userId, 'learning_items')}/${item.id}`, {
            status: 'notStarted',
            updatedAt: gateway.serverTimestamp(),
          });
        }
      }
    })());
  }

  await Promise.all(operations);
}
