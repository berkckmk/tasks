import { useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'expo-router';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { Alert, Pressable, ScrollView, Text, View } from 'react-native';
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
import {
  WEEKLY_WORKOUT_ROUTINE,
  getTodayRoutine,
  type DayRoutine,
} from '@/features/workout/workout-routine';
import {
  colors,
  getTabActiveColor,
  getTabColor,
  hexToRgba,
  radius,
  spacing,
  typography,
} from '@/theme';

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

  // Weekly workout routine state
  const todayRoutine = useMemo(() => getTodayRoutine(), []);
  const [selectedDayId, setSelectedDayId] = useState<string>(() => todayRoutine.dayId);
  const [showAllDays, setShowAllDays] = useState(false);
  const activeDay = useMemo(
    () => WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === selectedDayId) ?? todayRoutine,
    [selectedDayId, todayRoutine],
  );
  const themeActive = getTabActiveColor('workout');
  const themeColor = getTabColor('workout');

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

  function startRoutineWorkout(day: DayRoutine) {
    if (day.isRestDay || day.exercises.length === 0) return;
    setName(`${day.dayName} - ${day.focus}`);
    setDate(new Date());
    setDatePickerOpen(false);
    setExercises(
      day.exercises.map((ex) => ({
        key: nextExerciseKey.current++,
        name: ex.name,
        sets: String(ex.defaultSets),
        reps: String(ex.defaultReps),
        weight: '0',
      })),
    );
    setError(null);
    setSaving(false);
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
        tab="workout"
        subtitle="Antrenman ve egzersiz programlarınızı kaydedin, haftalık gelişiminizi takip edin."
        onBack={() => router.back()}
        onAdd={openCreate}
        addLabel="Antrenman ekle"
        hideFab={true}
      >
        {/* Özet ve Bugünkü Durum Kartı */}
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <AppCard style={{ flex: 1, padding: spacing.md, gap: 2 }}>
            <Kicker>Bu Haftaki Antrenman</Kicker>
            <AppText variant="h3" tone="inkAccent">{thisWeekCount}</AppText>
          </AppCard>

          <AppCard style={{ flex: 1, padding: spacing.md, gap: 2 }}>
            <Kicker>Bugünün Planı ({todayRoutine.dayShort})</Kicker>
            <AppText variant="title" numberOfLines={1} style={{ color: themeActive, fontWeight: '700' }}>
              {todayRoutine.focus}
            </AppText>
          </AppCard>
        </View>

        {/* HAFTALIK ANTRENMAN PROGRAMI BÖLÜMÜ */}
        <View style={{ gap: spacing.sm }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
            <View>
              <Kicker>GÜN BAZLI PROGRAM</Kicker>
              <AppText variant="h3">Haftalık Antrenman Planı</AppText>
            </View>
            <AppButton
              label={showAllDays ? 'Tek Güne Dön' : 'Tüm Haftayı Gör'}
              variant="text"
              size="sm"
              onPress={() => setShowAllDays((prev) => !prev)}
            />
          </View>

          {/* Gün Seçici Sekmeler (Pzt, Sal, Çar, Per, Cum, Cmt, Paz) */}
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ gap: spacing.xs, paddingVertical: 2 }}
          >
            {WEEKLY_WORKOUT_ROUTINE.map((day) => {
              const isSelected = selectedDayId === day.dayId;
              const isToday = day.dayId === todayRoutine.dayId;

              return (
                <Pressable
                  key={day.dayId}
                  onPress={() => {
                    setSelectedDayId(day.dayId);
                    if (showAllDays) setShowAllDays(false);
                  }}
                  style={{
                    paddingHorizontal: spacing.md,
                    paddingVertical: spacing.sm,
                    borderRadius: radius.pill,
                    backgroundColor: isSelected
                      ? hexToRgba(themeColor, 0.22)
                      : colors.surfaceElevated,
                    borderWidth: 1,
                    borderColor: isSelected ? themeActive : colors.border,
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 6,
                  }}
                >
                  <Text
                    style={{
                      ...typography.title,
                      color: isSelected ? themeActive : colors.text,
                      fontWeight: isSelected ? '700' : '500',
                    }}
                  >
                    {day.dayShort}
                  </Text>
                  {isToday ? (
                    <View
                      style={{
                        paddingHorizontal: 5,
                        paddingVertical: 1,
                        borderRadius: radius.pill,
                        backgroundColor: isSelected ? themeActive : hexToRgba(themeColor, 0.35),
                      }}
                    >
                      <Text
                        style={{
                          ...typography.metaSmall,
                          color: isSelected ? colors.surfaceElevated : themeActive,
                          fontWeight: '700',
                        }}
                      >
                        Bugün
                      </Text>
                    </View>
                  ) : null}
                </Pressable>
              );
            })}
          </ScrollView>

          {/* Program Kartı: Tek Gün veya Tüm Hafta */}
          {showAllDays ? (
            <View style={{ gap: spacing.sm }}>
              {WEEKLY_WORKOUT_ROUTINE.map((day) => (
                <RoutineDayCard
                  key={day.dayId}
                  day={day}
                  isToday={day.dayId === todayRoutine.dayId}
                  themeActive={themeActive}
                  themeColor={themeColor}
                  onStartWorkout={startRoutineWorkout}
                />
              ))}
            </View>
          ) : (
            <RoutineDayCard
              day={activeDay}
              isToday={activeDay.dayId === todayRoutine.dayId}
              themeActive={themeActive}
              themeColor={themeColor}
              onStartWorkout={startRoutineWorkout}
            />
          )}
        </View>

        {/* Üst Aksiyon Başlık Alanı - Geçmiş */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm, marginTop: spacing.xs }}>
          <AppText variant="h3">Antrenman Geçmişi</AppText>
          <AppButton
            label="+ Manuel Kayıt"
            size="sm"
            color={themeActive}
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

function RoutineDayCard({
  day,
  isToday,
  themeActive,
  themeColor,
  onStartWorkout,
}: {
  day: DayRoutine;
  isToday: boolean;
  themeActive: string;
  themeColor: string;
  onStartWorkout: (day: DayRoutine) => void;
}) {
  return (
    <AppCard style={{ gap: spacing.md, padding: spacing.md }}>
      {/* Gün ve Hedef Başlığı */}
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
        <View style={{ flex: 1, gap: 2 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
            <AppText variant="h3">{day.dayName}</AppText>
            {isToday ? (
              <View
                style={{
                  paddingHorizontal: spacing.sm,
                  paddingVertical: 2,
                  borderRadius: radius.pill,
                  backgroundColor: hexToRgba(themeColor, 0.25),
                }}
              >
                <Text style={{ ...typography.metaSmall, color: themeActive, fontWeight: '700' }}>
                  Bugün
                </Text>
              </View>
            ) : null}
          </View>
          <AppText variant="title" style={{ color: themeActive, fontWeight: '700' }}>
            {day.focus}
          </AppText>
          <AppText variant="caption" tone="muted">
            {day.targetGroups}
          </AppText>
        </View>

        <View
          style={{
            width: 44,
            height: 44,
            borderRadius: radius.pill,
            backgroundColor: hexToRgba(themeColor, 0.16),
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppIcon
            name={day.isRestDay ? 'moon' : 'barbell'}
            size={22}
            color={themeActive}
          />
        </View>
      </View>

      {/* Dinlenme veya Egzersiz Listesi */}
      {day.isRestDay ? (
        <View
          style={{
            padding: spacing.md,
            borderRadius: radius.card,
            backgroundColor: colors.surfaceMuted,
            gap: spacing.xs,
            alignItems: 'center',
          }}
        >
          <AppText variant="title" tone="text" style={{ textAlign: 'center' }}>
            {day.notes || 'Dinlenme ve Toparlanma'}
          </AppText>
          <AppText variant="bodySmall" tone="muted" style={{ textAlign: 'center' }}>
            Kas gelişimi ve eklem sağlığı için toparlanmaya ve uykuya özen gösterin.
          </AppText>
        </View>
      ) : (
        <>
          <View style={{ gap: spacing.xs }}>
            {day.exercises.map((ex, idx) => {
              const prevEx = idx > 0 ? day.exercises[idx - 1] : null;
              const isNewGroup = ex.muscleGroup && (!prevEx || prevEx.muscleGroup !== ex.muscleGroup);

              return (
                <View key={ex.id} style={{ gap: spacing.xs }}>
                  {isNewGroup ? (
                    <View
                      style={{
                        flexDirection: 'row',
                        alignItems: 'center',
                        gap: spacing.xs,
                        marginTop: idx > 0 ? spacing.sm : spacing.xs,
                        paddingTop: idx > 0 ? spacing.xs : 0,
                      }}
                    >
                      <View
                        style={{
                          width: 4,
                          height: 14,
                          borderRadius: radius.pill,
                          backgroundColor: themeActive,
                        }}
                      />
                      <Text
                        style={{
                          ...typography.metaSmall,
                          color: themeActive,
                          fontWeight: '700',
                          letterSpacing: 0.5,
                        }}
                      >
                        {ex.muscleGroup}
                      </Text>
                    </View>
                  ) : null}

                  <View
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      paddingVertical: spacing.sm,
                      borderBottomWidth: idx < day.exercises.length - 1 ? 1 : 0,
                      borderBottomColor: colors.divider,
                      gap: spacing.sm,
                    }}
                  >
                    <View style={{ flex: 1, gap: 2 }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
                        <Text style={{ ...typography.metaSmall, color: colors.muted, width: 20 }}>
                          {idx + 1}.
                        </Text>
                        <Text style={{ ...typography.title, color: colors.text, flex: 1 }}>
                          {ex.name}
                        </Text>
                      </View>
                      {ex.intensityNote ? (
                        <View style={{ paddingLeft: 28 }}>
                          <Text style={{ ...typography.metaSmall, color: colors.muted }}>
                            {ex.intensityNote}
                          </Text>
                        </View>
                      ) : null}
                    </View>

                    <View
                      style={{
                        paddingHorizontal: spacing.sm,
                        paddingVertical: 3,
                        borderRadius: radius.pill,
                        backgroundColor: hexToRgba(themeColor, 0.18),
                      }}
                    >
                      <Text style={{ ...typography.metaSmall, color: themeActive, fontWeight: '700' }}>
                        {ex.setsReps}
                      </Text>
                    </View>
                  </View>
                </View>
              );
            })}
          </View>

          <AppButton
            label="Bu Antrenmanı Kaydet"
            color={themeActive}
            icon={<AppIcon name="plus" size={16} color={colors.surfaceElevated} />}
            onPress={() => onStartWorkout(day)}
          />
        </>
      )}
    </AppCard>
  );
}
