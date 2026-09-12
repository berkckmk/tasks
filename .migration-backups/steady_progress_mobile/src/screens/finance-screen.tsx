import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useRouter } from 'expo-router';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { Alert, Pressable, Text, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, AppTextField, Kicker, ListEditorSheet, ListItemRow, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { expenseCategories, incomeCategories, monthlyFinanceSummary, savingsProgress, type FinanceTransaction, type SavingsGoal, type TransactionType } from '@/features/finance/finance';
import { FinanceRepository } from '@/features/finance/finance-repository';
import { colors, radius, spacing, typography } from '@/theme';

const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

export function FinanceScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new FinanceRepository(gateway, userId), [gateway, userId]);
  const [transactions, setTransactions] = useState<FinanceTransaction[]>([]);
  const [goals, setGoals] = useState<SavingsGoal[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [transactionOpen, setTransactionOpen] = useState(false);
  const [goalOpen, setGoalOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [type, setType] = useState<TransactionType>('expense');
  const [amount, setAmount] = useState('');
  const [category, setCategory] = useState<string>(expenseCategories[0]);
  const [note, setNote] = useState('');
  const [date, setDate] = useState(new Date());
  const [dateOpen, setDateOpen] = useState(false);
  const [goalId, setGoalId] = useState<string | null>(null);
  const [goalTitle, setGoalTitle] = useState('');
  const [target, setTarget] = useState('');
  const [current, setCurrent] = useState('0');

  useEffect(() => {
    const onError = (reason: unknown) => setError(String(reason));
    const stops = [repository.watchTransactions(setTransactions, onError), repository.watchSavingsGoals(setGoals, onError)];
    return () => stops.forEach((stop) => stop());
  }, [repository]);

  const summary = monthlyFinanceSummary(transactions);
  const firstGoal = goals[0];

  function openTransaction() {
    setType('expense');
    setAmount('');
    setCategory(expenseCategories[0]);
    setNote('');
    setDate(new Date());
    setError(null);
    setSaving(false);
    setTransactionOpen(true);
  }

  function openGoal(goal?: SavingsGoal) {
    setGoalId(goal?.id ?? null);
    setGoalTitle(goal?.title ?? '');
    setTarget(goal?.targetAmount.toFixed(2) ?? '');
    setCurrent(goal?.currentAmount.toFixed(2) ?? '0');
    setError(null);
    setSaving(false);
    setGoalOpen(true);
  }

  async function saveTransaction() {
    const value = Number(amount.replace(',', '.'));
    if (!Number.isFinite(value) || value <= 0) { setError('Geçerli bir tutar gir.'); return; }
    setSaving(true);
    try {
      await repository.addTransaction({ type, amount: value, category, note: note.trim(), date });
      setTransactionOpen(false);
    } catch (reason) { setError(String(reason)); } finally { setSaving(false); }
  }

  async function saveGoal() {
    const targetValue = Number(target.replace(',', '.'));
    const currentValue = Number(current.replace(',', '.'));
    if (!goalTitle.trim() || !Number.isFinite(targetValue) || targetValue <= 0 || !Number.isFinite(currentValue)) {
      setError('Başlık ve geçerli hedef tutarı gerekli.');
      return;
    }
    setSaving(true);
    try {
      await repository.saveSavingsGoal({ id: goalId ?? undefined, title: goalTitle.trim(), targetAmount: targetValue, currentAmount: currentValue, targetDate: null });
      setGoalOpen(false);
    } catch (reason) { setError(String(reason)); } finally { setSaving(false); }
  }

  return (
    <>
      <AppScreen tab="more">
        <PageHeaderGradient tab="more">
          <Pressable
            hitSlop={12}
            onPress={() => router.back()}
            accessibilityRole="button"
            accessibilityLabel="Geri"
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: spacing.xs,
              paddingVertical: 2,
              marginBottom: spacing.xs,
            }}
          >
            <AppIcon name="arrowLeft" size={18} tone="accent" />
            <AppText variant="meta" tone="muted">Geri</AppText>
          </Pressable>
          <View style={{ gap: spacing.xs }}>
            <AppText variant="h2">Finans</AppText>
            <AppText tone="muted">Gelir, gider ve birikim hedefini aynı düzen içinde izle.</AppText>
          </View>
        </PageHeaderGradient>

        {error && !transactionOpen && !goalOpen ? <AppText tone="error">{error}</AppText> : null}

        {/* İstatistikler */}
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <Stat label="Gelir" value={money.format(summary.income)} />
          <Stat label="Gider" value={money.format(summary.expenses)} />
          <Stat label="Birikim" value={`${Math.round(summary.savingsRate * 100)}%`} />
        </View>

        {/* Birikim Hedefi Kartı */}
        <View style={{ gap: spacing.xs }}>
          <Kicker>Birikim hedefi</Kicker>
          {firstGoal ? (
            <AppCard style={{ padding: spacing.md, gap: spacing.xs }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                <AppText variant="title">{firstGoal.title}</AppText>
                <Pressable hitSlop={8} onPress={() => openGoal(firstGoal)}>
                  <Text style={{ ...typography.meta, color: colors.inkAccent }}>Düzenle</Text>
                </Pressable>
              </View>
              <AppText tone="muted">
                {money.format(firstGoal.currentAmount)} / {money.format(firstGoal.targetAmount)} · %{Math.round(savingsProgress(firstGoal) * 100)}
              </AppText>
              <View style={{ height: 4, backgroundColor: colors.divider, borderRadius: radius.pill, marginTop: 4, overflow: 'hidden' }}>
                <View style={{ height: '100%', width: `${Math.min(100, Math.round(savingsProgress(firstGoal) * 100))}%`, backgroundColor: colors.inkAccent, borderRadius: radius.pill }} />
              </View>
            </AppCard>
          ) : (
            <AppCard style={{ padding: spacing.md, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
              <AppText tone="muted">Henüz birikim hedefi yok.</AppText>
              <AppButton label="Hedef belirle" variant="text" size="sm" onPress={() => openGoal()} />
            </AppCard>
          )}
        </View>

        {/* Son İşlemler Başlığı ve Aksiyon Butonu */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <AppText variant="h3">Son İşlemler</AppText>
          <AppButton
            label="+ Yeni İşlem"
            size="sm"
            color={colors.tabMore}
            onPress={openTransaction}
          />
        </View>

        {transactions.length ? (
          <View style={{ gap: spacing.sm }}>
            {transactions.map((item) => (
              <ListItemRow
                key={item.id}
                title={item.category}
                subtitle={`${new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'short', year: 'numeric' }).format(item.date)}${item.note ? ` · ${item.note}` : ''}`}
                trailing={
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
                    <Text style={{ ...typography.title, color: item.type === 'income' ? colors.inkAccent : colors.text }}>
                      {item.type === 'income' ? '+' : '-'}{money.format(item.amount)}
                    </Text>
                    <Pressable
                      hitSlop={8}
                      onPress={() => Alert.alert('İşlem silinsin mi?', 'Bu işlem geri alınamaz.', [
                        { text: 'İptal', style: 'cancel' },
                        { text: 'Sil', style: 'destructive', onPress: () => void repository.deleteTransaction(item.id) },
                      ])}
                      style={{ padding: 4 }}
                    >
                      <AppIcon name="trash" size={16} tone="muted" />
                    </Pressable>
                  </View>
                }
              />
            ))}
          </View>
        ) : (
          <View style={{ alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xxl, gap: spacing.xs }}>
            <AppText variant="title" tone="text" style={{ textAlign: 'center' }}>
              Henüz işlem yok
            </AppText>
            <AppText variant="bodySmall" tone="muted" style={{ textAlign: 'center', paddingHorizontal: spacing.lg }}>
              Yukarıdaki + Yeni İşlem butonu ile gelir ve giderlerinizi kaydedebilirsiniz.
            </AppText>
          </View>
        )}
      </AppScreen>

      <ListEditorSheet presented={transactionOpen} title="İşlem ekle" error={transactionOpen ? error : null} saving={saving} onDismiss={() => setTransactionOpen(false)} onSave={() => void saveTransaction()}>
        <Choice label="Tür"><AppButton size="sm" label="Gider" variant={type === 'expense' ? 'primary' : 'text'} onPress={() => { setType('expense'); setCategory(expenseCategories[0]); }} /><AppButton size="sm" label="Gelir" variant={type === 'income' ? 'primary' : 'text'} onPress={() => { setType('income'); setCategory(incomeCategories[0]); }} /></Choice>
        <AppTextField label="Tutar" value={amount} onChangeText={setAmount} keyboardType="decimal-pad" />
        <Choice label="Kategori">{(type === 'income' ? incomeCategories : expenseCategories).map((value) => <AppButton key={value} size="sm" label={value} variant={category === value ? 'primary' : 'text'} onPress={() => setCategory(value)} />)}</Choice>
        <AppTextField label="Not (isteğe bağlı)" value={note} onChangeText={setNote} />
        <AppButton label={new Intl.DateTimeFormat('tr-TR', { dateStyle: 'medium' }).format(date)} variant="secondary" onPress={() => setDateOpen(true)} />{dateOpen ? <DateTimePicker value={date} mode="date" accentColor={colors.accent} themeVariant="light" onValueChange={(_event, value) => { setDate(value); setDateOpen(false); }} onDismiss={() => setDateOpen(false)} /> : null}
      </ListEditorSheet>

      <ListEditorSheet presented={goalOpen} title="Birikim hedefi" error={goalOpen ? error : null} saving={saving} onDismiss={() => setGoalOpen(false)} onSave={() => void saveGoal()} deleteLabel={goalId ? 'Hedefi sil' : undefined} onDelete={goalId ? () => Alert.alert('Hedef silinsin mi?', 'Bu işlem geri alınamaz.', [{ text: 'İptal', style: 'cancel' }, { text: 'Sil', style: 'destructive', onPress: async () => { await repository.deleteSavingsGoal(goalId); setGoalOpen(false); } }]) : undefined}>
        <AppTextField label="Hedef adı" value={goalTitle} onChangeText={setGoalTitle} />
        <AppTextField label="Hedef tutarı" value={target} onChangeText={setTarget} keyboardType="decimal-pad" />
        <AppTextField label="Şimdiye kadar biriken" value={current} onChangeText={setCurrent} keyboardType="decimal-pad" />
      </ListEditorSheet>
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <AppCard style={{ flex: 1, padding: spacing.sm, borderRadius: radius.sm, gap: 2 }}>
      <Kicker>{label}</Kicker>
      <AppText variant="title">{value}</AppText>
    </AppCard>
  );
}

function Choice({ label, children }: { label: string; children: ReactNode }) {
  return (
    <View style={{ gap: spacing.sm }}>
      <Kicker>{label}</Kicker>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>{children}</View>
    </View>
  );
}
