import { getAuth } from '@react-native-firebase/auth';
import SteadyWidget from '../../../modules/steady-widget';
import { FirebaseDataGateway } from '../../core/data/firebase-data-gateway';
import { userCollection } from '../../core/data/data-gateway';
import { formatLogDate, habitFromDocument, habitLogFromDocument, mergeHabitsWithLogs } from '../habits/habit';
import { reminderFromDocument } from '../reminders/reminder';
import { taskFromDocument } from '../tasks/task-item';
import { buildWidgetSnapshot } from './widget-snapshot';

async function authenticatedUserId(): Promise<string | null> {
  const current = getAuth().currentUser;
  if (current) return current.uid;
  return await new Promise((resolve) => {
    const timeout = setTimeout(() => { stop(); resolve(null); }, 5_000);
    const stop = getAuth().onAuthStateChanged((user) => {
      clearTimeout(timeout);
      stop();
      resolve(user?.uid ?? null);
    });
  });
}

/** One-shot reconciliation used by data-only FCM while no UI is mounted. */
export async function refreshWidgetInBackground(): Promise<boolean> {
  if (!SteadyWidget) return false;
  const userId = await authenticatedUserId();
  if (!userId) return false;
  const gateway = new FirebaseDataGateway();
  const cutoff = formatLogDate(new Date());

  const [habitRows, logRows, taskRows, reminderRows] = await Promise.all([
    gateway.getCollection(userCollection(userId, 'habits'), { orderBy: { field: 'createdAt' }, limit: 200 }),
    gateway.getCollection(userCollection(userId, 'habit_logs'), { filters: [{ field: 'date', operator: '>=', value: cutoff }] }),
    gateway.getCollection(userCollection(userId, 'tasks'), { orderBy: { field: 'createdAt', direction: 'desc' }, limit: 200 }),
    gateway.getCollection(userCollection(userId, 'reminders'), { orderBy: { field: 'dueAt' } }),
  ]);

  const habits = mergeHabitsWithLogs(
    habitRows.map((row) => habitFromDocument(row.id, row.data)),
    logRows.map((row) => habitLogFromDocument(row.id, row.data)),
  );
  const tasks = taskRows.map((row) => taskFromDocument(row.id, row.data));
  const reminders = reminderRows.map((row) => reminderFromDocument(row.id, row.data));
  return SteadyWidget.updateWidget(buildWidgetSnapshot({ habits, tasks, reminders }));
}
