import { addCalendarDays, formatLogDate, type Habit, type HabitLog } from '../habits/habit.ts';
import { goalProgress, type Goal } from '../goals/goal.ts';
import type { TaskItem } from '../tasks/task-item.ts';
export type WeekCompletion = { weekLabel: string; habitCompletionRate: number; taskCompletionRate: number | null };
export type AnalyticsSummary = { weeklyBreakdown: WeekCompletion[]; goalProgressAverage: number; bestStreak: number; mostConsistentHabitName: string | null; productivityScore: number };
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
function monday(date: Date) { const value = new Date(date.getFullYear(), date.getMonth(), date.getDate()); return addCalendarDays(value, -((value.getDay() + 6) % 7)); }
export function buildAnalyticsSummary({ habits, logs, tasks, goals, now = new Date() }: { habits: Habit[]; logs: HabitLog[]; tasks: TaskItem[]; goals: Goal[]; now?: Date }): AnalyticsSummary {
  const completed = new Map<string, Set<string>>(); for (const log of logs) if (log.completed) { const dates = completed.get(log.habitId) ?? new Set<string>(); dates.add(log.date); completed.set(log.habitId, dates); }
  const today = formatLogDate(now); const weeks: WeekCompletion[] = [];
  for (let i = 3; i >= 0; i -= 1) { const start = addCalendarDays(monday(now), -7 * i); const end = addCalendarDays(start, 7); let habitDone = 0; let elapsed = 0; for (let d = 0; d < 7; d += 1) { const value = addCalendarDays(start, d); const label = formatLogDate(value); if (label > today) break; elapsed += 1; for (const habit of habits) if (completed.get(habit.id)?.has(label)) habitDone += 1; } const due = tasks.filter((task) => task.dueDate && task.dueDate >= start && task.dueDate < end); weeks.push({ weekLabel: `${months[start.getMonth()]} ${start.getDate()}`, habitCompletionRate: habits.length * elapsed ? habitDone / (habits.length * elapsed) : 0, taskCompletionRate: due.length ? due.filter((task) => task.status === 'done').length / due.length : null }); }
  const goalAverage = goals.length ? goals.reduce((sum, goal) => sum + goalProgress(goal), 0) / goals.length : 0; const bestStreak = habits.length ? Math.max(...habits.map((habit) => habit.streak)) : 0; const consistent = habits.length ? habits.reduce((a, b) => (completed.get(a.id)?.size ?? 0) >= (completed.get(b.id)?.size ?? 0) ? a : b).name : null; const latest = weeks.at(-1)!; const score = Math.round((latest.habitCompletionRate * .4 + (latest.taskCompletionRate ?? 0) * .4 + goalAverage * .2) * 100);
  return { weeklyBreakdown: weeks, goalProgressAverage: goalAverage, bestStreak, mostConsistentHabitName: consistent, productivityScore: Math.max(0, Math.min(100, score)) };
}
