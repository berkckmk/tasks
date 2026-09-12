import { dateFromFirestore } from '../../core/data/firestore-values.ts';

export type Workout = {
  id: string;
  name: string;
  date: Date;
};

export type ExerciseLog = {
  id: string;
  workoutId: string;
  name: string;
  sets: number;
  reps: number;
  weight: number;
  isPersonalRecord: boolean;
};

export type ExerciseDraft = Pick<ExerciseLog, 'name' | 'sets' | 'reps' | 'weight'>;

function finiteNumber(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

export function workoutFromDocument(id: string, data: Record<string, unknown>): Workout {
  return {
    id,
    name: typeof data.name === 'string' ? data.name : '',
    date: dateFromFirestore(data.date) ?? new Date(),
  };
}

export function exerciseLogFromDocument(id: string, data: Record<string, unknown>): ExerciseLog {
  return {
    id,
    workoutId: typeof data.workoutId === 'string' ? data.workoutId : '',
    name: typeof data.name === 'string' ? data.name : '',
    sets: Math.trunc(finiteNumber(data.sets)),
    reps: Math.trunc(finiteNumber(data.reps)),
    weight: finiteNumber(data.weight),
    isPersonalRecord: data.isPersonalRecord === true,
  };
}

/** Monday at local midnight. Calendar arithmetic avoids DST-related 23:00/01:00 drift. */
export function startOfLocalWeek(date: Date) {
  const midnight = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const mondayOffset = (midnight.getDay() + 6) % 7;
  return new Date(midnight.getFullYear(), midnight.getMonth(), midnight.getDate() - mondayOffset);
}
