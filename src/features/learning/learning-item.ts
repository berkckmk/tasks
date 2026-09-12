import { enumValue, stringList } from '../../core/data/firestore-values.ts';

export const learningTypes = ['book', 'course', 'podcast'] as const;
export const learningStatuses = ['planned', 'inProgress', 'completed'] as const;
export type LearningType = typeof learningTypes[number];
export type LearningStatus = typeof learningStatuses[number];

export type LearningItem = {
  id: string;
  title: string;
  type: LearningType;
  status: LearningStatus;
  rating: number;
  notes: string;
  keyTakeaways: string[];
};

export function learningItemFromDocument(id: string, data: Record<string, unknown>): LearningItem {
  const rawRating = typeof data.rating === 'number' ? Math.trunc(data.rating) : 0;
  return {
    id,
    title: typeof data.title === 'string' ? data.title : '',
    type: enumValue(data.type, learningTypes, 'book'),
    status: enumValue(data.status, learningStatuses, 'planned'),
    rating: Math.max(0, Math.min(5, rawRating)),
    notes: typeof data.notes === 'string' ? data.notes : '',
    keyTakeaways: stringList(data.keyTakeaways),
  };
}
