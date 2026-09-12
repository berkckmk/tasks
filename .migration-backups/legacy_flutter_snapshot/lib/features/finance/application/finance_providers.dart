import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_finance_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/savings_goal.dart';

// Module streams below are `autoDispose`: each is watched only by its own
// screen, so the Firestore listener closes when the user navigates away
// instead of staying open for the rest of the session. Nothing outside the
// widget tree watches them, which is what makes this safe — a non-autoDispose
// provider cannot watch an autoDispose one.
final financeRepositoryProvider = Provider.autoDispose<FinanceRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreFinanceRepository(ref.watch(firestoreProvider), uid);
});

final financeTransactionsProvider = StreamProvider.autoDispose<List<FinanceTransaction>>((ref) {
  final repository = ref.watch(financeRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchTransactions();
});

final savingsGoalsProvider = StreamProvider.autoDispose<List<SavingsGoal>>((ref) {
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
