import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import {
  exerciseLogFromDocument,
  workoutFromDocument,
  type ExerciseDraft,
  type ExerciseLog,
  type Workout,
} from './workout.ts';

export type LogWorkoutInput = {
  name: string;
  date: Date;
  exercises: ExerciseDraft[];
};

export class WorkoutRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watchWorkouts(onData: (items: Workout[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'workouts'),
      { orderBy: { field: 'date', direction: 'desc' }, limit: 200 },
      (rows) => onData(rows.map((row) => workoutFromDocument(row.id, row.data))),
      onError,
    );
  }

  watchExerciseLogs(
    onData: (items: ExerciseLog[]) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'exercise_logs'),
      {},
      (rows) => onData(rows.map((row) => exerciseLogFromDocument(row.id, row.data))),
      onError,
    );
  }

  async logWorkout(input: LogWorkoutInput) {
    const workouts = userCollection(this.userId, 'workouts');
    const logs = userCollection(this.userId, 'exercise_logs');
    const workout = await this.gateway.addDocument(workouts, {
      name: input.name,
      date: input.date,
      createdAt: this.gateway.serverTimestamp(),
    });
    const createdLogPaths: string[] = [];
    try {
      for (const exercise of input.exercises) {
        const log = await this.gateway.addDocument(logs, {
          workoutId: workout.id,
          name: exercise.name,
          sets: exercise.sets,
          reps: exercise.reps,
          weight: exercise.weight,
          isPersonalRecord: false,
          date: input.date,
        });
        createdLogPaths.push(`${logs}/${log.id}`);
      }
      return workout.id;
    } catch (error) {
      await this.gateway.deleteDocuments(createdLogPaths);
      await this.gateway.deleteDocument(`${workouts}/${workout.id}`);
      throw error;
    }
  }

  async deleteWorkout(workoutId: string) {
    const logs = userCollection(this.userId, 'exercise_logs');
    const orphanedLogs = await this.gateway.getCollection(logs, {
      filters: [{ field: 'workoutId', operator: '==', value: workoutId }],
    });
    await this.gateway.deleteDocuments(orphanedLogs.map((row) => `${logs}/${row.id}`));
    await this.gateway.deleteDocument(`${userCollection(this.userId, 'workouts')}/${workoutId}`);
  }
}
