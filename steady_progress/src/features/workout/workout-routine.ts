export type RoutineExercise = {
  id: string;
  name: string;
  setsReps: string;
  defaultSets: number;
  defaultReps: number;
  intensityNote: string;
};

export type DayRoutine = {
  dayId: 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun';
  dayIndex: number; // 1 = Pazartesi, ..., 6 = Cumartesi, 0 = Pazar (JavaScript getDay())
  dayName: string;
  dayShort: string;
  focus: string;
  targetGroups: string;
  isRestDay: boolean;
  notes?: string;
  exercises: RoutineExercise[];
};

export const WEEKLY_WORKOUT_ROUTINE: DayRoutine[] = [
  {
    dayId: 'mon',
    dayIndex: 1,
    dayName: 'Pazartesi',
    dayShort: 'Pzt',
    focus: 'İtiş',
    targetGroups: 'Göğüs Odaklı, Omuz, Triceps',
    isRestDay: false,
    exercises: [
      {
        id: 'mon-1',
        name: 'Plate Loaded Chest Press',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'mon-2',
        name: 'Smith Machine Low Incline Press',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'mon-3',
        name: 'Shoulder Press Machine',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'mon-4',
        name: 'Lateral Raise (Kablo/Makine)',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: 'Kontrollü negatif',
      },
      {
        id: 'mon-5',
        name: 'Triceps Pushdown',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'mon-6',
        name: 'Overhead Rope Extension',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
    ],
  },
  {
    dayId: 'tue',
    dayIndex: 2,
    dayName: 'Salı',
    dayShort: 'Sal',
    focus: 'Çekiş & Bacak',
    targetGroups: 'Dikey Çekiş, Biceps, Eklem Dostu Bacak',
    isRestDay: false,
    exercises: [
      {
        id: 'tue-1',
        name: 'Lat Pulldown',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'tue-2',
        name: 'Plate Loaded Wide Grip Row',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'tue-3',
        name: 'Cable Curl',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'tue-4',
        name: 'Hammer Curl',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'tue-5',
        name: 'Seated Leg Curl',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: 'Yavaş tempo, eksenel yük yok',
      },
      {
        id: 'tue-6',
        name: 'Leg Extension',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: 'Düşük kilo, yumuşak tepe açısı',
      },
      {
        id: 'tue-7',
        name: 'Standing / Seated Calf Raise',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: 'Kontrollü esneme',
      },
    ],
  },
  {
    dayId: 'wed',
    dayIndex: 3,
    dayName: 'Çarşamba',
    dayShort: 'Çar',
    focus: 'Dinlenme (Rest)',
    targetGroups: 'Aktif toparlanma & eklem mobilitesi',
    isRestDay: true,
    notes: 'Aktif toparlanma & eklem mobilitesi',
    exercises: [],
  },
  {
    dayId: 'thu',
    dayIndex: 4,
    dayName: 'Perşembe',
    dayShort: 'Per',
    focus: 'İtiş',
    targetGroups: 'Omuz Odaklı, Göğüs, Triceps',
    isRestDay: false,
    exercises: [
      {
        id: 'thu-1',
        name: 'Shoulder Press Machine',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'thu-2',
        name: 'Lateral Raise (Kablo)',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'Sabit gerilim',
      },
      {
        id: 'thu-3',
        name: 'Smith Machine Low Incline Press',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'thu-4',
        name: 'Chest Fly Machine (Pec Deck)',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'Kontrollü açılış',
      },
      {
        id: 'thu-5',
        name: 'Cable Rear Delt Fly',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'thu-6',
        name: 'Triceps Pushdown',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
    ],
  },
  {
    dayId: 'fri',
    dayIndex: 5,
    dayName: 'Cuma',
    dayShort: 'Cum',
    focus: 'Çekiş & Bacak',
    targetGroups: 'Yatay Çekiş, Biceps, Eklem Dostu Bacak',
    isRestDay: false,
    exercises: [
      {
        id: 'fri-1',
        name: 'Chest-Supported Row / Cable Row',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'Bel desteği tam, RIR 1',
      },
      {
        id: 'fri-2',
        name: 'Close Grip Lat Pulldown',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1',
      },
      {
        id: 'fri-3',
        name: 'Dumbbell Incline / Preacher Curl',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'fri-4',
        name: 'Reverse Grip Cable Curl',
        setsReps: '2 × 10',
        defaultSets: 2,
        defaultReps: 10,
        intensityNote: 'RIR 1-2',
      },
      {
        id: 'fri-5',
        name: 'Leg Extension',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: '3 sn negatif iniş',
      },
      {
        id: 'fri-6',
        name: 'Seated Leg Curl',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: 'Yavaş ve kontrollü tempo',
      },
      {
        id: 'fri-7',
        name: 'Cable Crunch',
        setsReps: '2 × 10-12',
        defaultSets: 2,
        defaultReps: 12,
        intensityNote: 'Omurgayı ezmeden izole sıkıştırma',
      },
    ],
  },
  {
    dayId: 'sat',
    dayIndex: 6,
    dayName: 'Cumartesi',
    dayShort: 'Cmt',
    focus: 'Dinlenme / Eksik Bölge',
    targetGroups: 'Tam dinlenme veya hafif izole kol',
    isRestDay: true,
    notes: 'Tam dinlenme veya hafif izole kol (Opsiyonel)',
    exercises: [],
  },
  {
    dayId: 'sun',
    dayIndex: 0,
    dayName: 'Pazar',
    dayShort: 'Paz',
    focus: 'Dinlenme (Rest)',
    targetGroups: 'Tam toparlanma',
    isRestDay: true,
    notes: 'Tam toparlanma',
    exercises: [],
  },
];

/**
 * Returns the day routine for the given date (defaults to today).
 * Sunday is index 0 in JS Date.
 */
export function getTodayRoutine(date: Date = new Date()): DayRoutine {
  const dayIndex = date.getDay();
  return WEEKLY_WORKOUT_ROUTINE.find((r) => r.dayIndex === dayIndex) ?? WEEKLY_WORKOUT_ROUTINE[0];
}
