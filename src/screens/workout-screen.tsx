import { useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'expo-router';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { Alert, Pressable, View } from 'react-native';
import {
  AppButton,
  AppCard,
  AppIcon,
  AppText,
  AppTextField,
  Kicker,
  ListEditorSheet,
  ListScreenShell,
  ListItemRow,
} from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import {
  startOfLocalWeek,
  type ExerciseLog,
  type Workout,
} from '@/features/workout/workout';
import { WorkoutRepository } from '@/features/workout/workout-repository';
import { colors, spacing } from '@/theme';

type ExerciseInput = {
  key: number;
  name: string;
  sets: string;
  reps: string;
  weight: string;
};

function dateLabel(date: Date) {
  return new Intl.DateTimeFormat('tr-TR', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}

function newExercise(key: number): ExerciseInput {
  return { key, name: '', sets: '3', reps: '10', weight: '0' };
}

export function WorkoutScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new WorkoutRepository(gateway, userId), [gateway, userId]);
  const nextExerciseKey = useRef(1);
  const [workouts, setWorkouts] = useState<Workout[]>([]);
  const [logs, setLogs] = useState<ExerciseLog[]>([]);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [name, setName] = useState('');
  const [date, setDate] = useState(() => new Date());
  const [datePickerOpen, setDatePickerOpen] = useState(false);
  const [exercises, setExercises] = useState<ExerciseInput[]>([newExercise(0)]);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const stopWorkouts = repository.watchWorkouts(setWorkouts, (reason) => setError(String(reason)));
    const stopLogs = repository.watchExerciseLogs(setLogs, (reason) => setError(String(reason)));
    return () => {
      stopWorkouts();
      stopLogs();
    };
  }, [repository]);

  const logsByWorkout = useMemo(() => {
    const grouped = new Map<string, ExerciseLog[]>();
    for (const log of logs) {
      const group = grouped.get(log.workoutId) ?? [];
      group.push(log);
      grouped.set(log.workoutId, group);
    }
    return grouped;
  }, [logs]);

  const thisWeekCount = useMemo(() => {
    const weekStart = startOfLocalWeek(new Date());
    return workouts.filter((workout) => workout.date >= weekStart).length;
  }, [workouts]);

  function resetForm() {
    setName('');
    setDate(new Date());
    setDatePickerOpen(false);
    setExercises([newExercise(nextExerciseKey.current++)]);
    setError(null);
    setSaving(false);
  }

  function openCreate() {
    resetForm();
    setSheetOpen(true);
  }

  function close() {
    setSheetOpen(false);
    resetForm();
    setSaving(false);
  }

  function updateExercise(key: number, field: keyof Omit<ExerciseInput, 'key'>, value: string) {
    setExercises((current) => current.map((exercise) => (
      exercise.key === key ? { ...exercise, [field]: value } : exercise
    )));
  }

  async function save() {
    const trimmedName = name.trim();
    if (!trimmedName) {
      setError('Lütfen bir antrenman adı girin.');
      return;
    }
    const drafts = exercises
      .filter((exercise) => exercise.name.trim())
      .map((exercise) => ({
        name: exercise.name.trim(),
        sets: Number.parseInt(exercise.sets.trim(), 10) || 0,
        reps: Number.parseInt(exercise.reps.trim(), 10) || 0,
        weight: Number.parseFloat(exercise.weight.trim()) || 0,
      }));
    setSaving(true);
    try {
      await repository.logWorkout({ name: trimmedName, date, exercises: drafts });
      close();
    } catch (reason) {
      setError(String(reason));
    } finally {
      setSaving(false);
    }
  }

  function confirmDelete(workout: Workout) {
    Alert.alert(
      'Antrenmanı sil',
      `“${workout.name}” ve bu kayda ait tüm egzersizler kalıcı olarak silinecek.`,
      [
        { text: 'Vazgeç', style: 'cancel' },
        {
          text: 'Sil',
          style: 'destructive',
          onPress: () => void repository.deleteWorkout(workout.id).catch((reason) => setError(String(reason))),
        },
      ],
    );
  }

  return (
    <>
      <ListScreenShell
        title="Antrenman"
        subtitle="Antrenman ve egzersiz programlarınızı kaydedin, haftalık gelişiminizi takip edin."
        onBack={() => router.back()}
        onAdd={openCreate}
        addLabel="Antrenman ekle"
        hideFab={true}
      >
        <AppCard style={{ padding: spacing.md, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Kicker>Bu haftaki antrenmanlar</Kicker>
          <AppText variant="h3" tone="inkAccent">{thisWeekCount}</AppText>
        </AppCard>

        {/* Üst Aksiyon Başlık Alanı */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <AppText variant="h3">Antrenman Geçmişi</AppText>
          <AppButton
            label="+ Yeni Antrenman"
            size="sm"
            color={colors.tabMore}
            onPress={openCreate}
          />
        </View>

        {error && !sheetOpen ? <AppText accessibilityRole="alert" tone="error">{error}</AppText> : null}

        {workouts.length === 0 ? (
          <View style={{ alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xxl, gap: spacing.xs }}>
            <AppText variant="title" tone="text" style={{ textAlign: 'center' }}>
              Henüz antrenman kaydı yok
            </AppText>
            <AppText variant="bodySmall" tone="muted" style={{ textAlign: 'center', paddingHorizontal: spacing.lg }}>
              Yukarıdaki + Yeni Antrenman butonu ile egzersiz ve setlerinizi kaydetmeye başlayabilirsiniz.
            </AppText>
          </View>
        ) : (
          <View style={{ gap: spacing.sm }}>
            {workouts.map((workout) => {
              const exercises = logsByWorkout.get(workout.id) ?? [];
              const exerciseSummary = exercises
                .map((e) => `${e.name} ${e.sets}×${e.reps}${e.weight ? ` @ ${e.weight.toFixed(0)}kg` : ''}${e.isPersonalRecord ? ' (PR)' : ''}`)
                .join(', ');

              return (
                <ListItemRow
                  key={workout.id}
                  title={workout.name}
                  subtitle={dateLabel(workout.date)}
                  note={exerciseSummary || null}
                  trailing={
                    <Pressable
                      hitSlop={8}
                      onPress={() => confirmDelete(workout)}
                      style={{ padding: 4 }}
                    >
                      <AppIcon name="trash" size={16} tone="muted" />
                    </Pressable>
                  }
                />
              );
            })}
          </View>
        )}
      </ListScreenShell>
      <ListEditorSheet
        presented={sheetOpen}
        title="Antrenman kaydet"
        error={error}
        saving={saving}
        onDismiss={close}
        onSave={() => void save()}
      >
        <AppTextField
          autoFocus
          label="Antrenman adı"
          placeholder="Örn: Göğüs & Ön Kol"
          value={name}
          onChangeText={setName}
        />
        <View style={{ gap: spacing.sm }}>
          <Kicker>Tarih</Kicker>
          <AppButton label={dateLabel(date)} variant="secondary" onPress={() => setDatePickerOpen(true)} />
          {datePickerOpen ? (
            <DateTimePicker
              value={date}
              mode="date"
              minimumDate={new Date(new Date().getFullYear() - 1, new Date().getMonth(), new Date().getDate())}
              maximumDate={new Date()}
              accentColor={colors.accent}
              themeVariant="light"
              positiveButton={{ label: 'Seç' }}
              negativeButton={{ label: 'Vazgeç' }}
              onValueChange={(_event, value) => {
                setDate(new Date(value.getFullYear(), value.getMonth(), value.getDate()));
                setDatePickerOpen(false);
              }}
              onDismiss={() => setDatePickerOpen(false)}
            />
          ) : null}
        </View>
        <View style={{ gap: spacing.md }}>
          <Kicker>Egzersizler</Kicker>
          {exercises.map((exercise, index) => (
            <AppCard key={exercise.key}>
              <AppTextField
                label={`Egzersiz ${index + 1}`}
                placeholder="Egzersiz adı"
                value={exercise.name}
                onChangeText={(value) => updateExercise(exercise.key, 'name', value)}
              />
              <View style={{ flexDirection: 'row', gap: spacing.sm }}>
                <AppTextField
                  label="Set"
                  value={exercise.sets}
                  keyboardType="number-pad"
                  selectTextOnFocus
                  containerStyle={{ flex: 1 }}
                  onChangeText={(value) => updateExercise(exercise.key, 'sets', value)}
                />
                <AppTextField
                  label="Tekrar"
                  value={exercise.reps}
                  keyboardType="number-pad"
                  selectTextOnFocus
                  containerStyle={{ flex: 1 }}
                  onChangeText={(value) => updateExercise(exercise.key, 'reps', value)}
                />
                <AppTextField
                  label="kg"
                  value={exercise.weight}
                  keyboardType="decimal-pad"
                  selectTextOnFocus
                  containerStyle={{ flex: 1 }}
                  onChangeText={(value) => updateExercise(exercise.key, 'weight', value)}
                />
              </View>
              {exercises.length > 1 ? (
                <AppButton
                  label="Egzersizi kaldır"
                  size="sm"
                  variant="text"
                  onPress={() => setExercises((current) => current.filter((item) => item.key !== exercise.key))}
                />
              ) : null}
            </AppCard>
          ))}
          <AppButton
            label="+ Egzersiz ekle"
            variant="text"
            onPress={() => setExercises((current) => [
              ...current,
              newExercise(nextExerciseKey.current++),
            ])}
          />
        </View>
      </ListEditorSheet>
    </>
  );
}
