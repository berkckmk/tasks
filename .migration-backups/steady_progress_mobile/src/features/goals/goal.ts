import { dateFromFirestore, enumValue } from '../../core/data/firestore-values.ts';
export const goalCategories = ['career', 'finance', 'health', 'learning', 'personal'] as const;
export const goalProgressTypes = ['percentage', 'milestones'] as const;
export type GoalCategory = typeof goalCategories[number];
export type GoalProgressType = typeof goalProgressTypes[number];
export type Milestone = { id: string; title: string; isDone: boolean };
export type Goal = { id: string; title: string; description: string; category: GoalCategory; targetDate: Date | null; progressType: GoalProgressType; manualProgress: number; milestones: Milestone[] };
export function goalProgress(goal: Goal) { if (goal.progressType === 'percentage' || !goal.milestones.length) return goal.manualProgress; return goal.milestones.filter((item) => item.isDone).length / goal.milestones.length; }
export function goalFromDocument(id: string, data: Record<string, unknown>): Goal {
  const milestones = Array.isArray(data.milestones) ? data.milestones.flatMap((value) => {
    if (!value || typeof value !== 'object') return [];
    const row = value as Record<string, unknown>;
    return [{ id: typeof row.id === 'string' ? row.id : '', title: typeof row.title === 'string' ? row.title : '', isDone: row.isDone === true }];
  }) : [];
  const progress = typeof data.manualProgress === 'number' && Number.isFinite(data.manualProgress) ? data.manualProgress : 0;
  return { id, title: typeof data.title === 'string' ? data.title : '', description: typeof data.description === 'string' ? data.description : '', category: enumValue(data.category, goalCategories, 'personal'), targetDate: dateFromFirestore(data.targetDate), progressType: enumValue(data.progressType, goalProgressTypes, 'percentage'), manualProgress: Math.max(0, Math.min(1, progress)), milestones };
}
