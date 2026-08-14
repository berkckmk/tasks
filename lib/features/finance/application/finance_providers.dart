import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_finance_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/savings_goal.dart';

final financeRepositoryProvider = Provider<FinanceRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreFinanceRepository(ref.watch(firestoreProvider), uid);
});

final financeTransactionsProvider = StreamProvider<List<FinanceTransaction>>((ref) {
  final repository = ref.watch(financeRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchTransactions();
});

final savingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final repository = ref.watch(financeRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchSavingsGoals();
});

class FinanceActions {
  FinanceActions(this._ref);

  final Ref _ref;

  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
  }) async {
    final repository = _ref.read(financeRepositoryProvider);
    if (repository == null) return;
    await repository.addTransaction(
      type: type,
      amount: amount,
      category: category,
      note: note,
      date: date,
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final repository = _ref.read(financeRepositoryProvider);
    if (repository == null) return;
    await repository.deleteTransaction(transactionId);
  }

  Future<void> saveSavingsGoal({
    String? id,
    required String title,
    required double targetAmount,
    required double currentAmount,
    DateTime? targetDate,
  }) async {
    final repository = _ref.read(financeRepositoryProvider);
    if (repository == null) return;
    await repository.saveSavingsGoal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
    );
  }
}

final financeActionsProvider = Provider<FinanceActions>((ref) => FinanceActions(ref));
