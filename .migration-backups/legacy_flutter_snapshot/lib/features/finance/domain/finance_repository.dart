import 'finance_transaction.dart';
import 'savings_goal.dart';

abstract class FinanceRepository {
  Stream<List<FinanceTransaction>> watchTransactions();

  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
  });

  Future<void> deleteTransaction(String transactionId);

  Stream<List<SavingsGoal>> watchSavingsGoals();

  Future<void> saveSavingsGoal({
    required String? id,
    required String title,
    required double targetAmount,
    required double currentAmount,
    required DateTime? targetDate,
  });

  Future<void> deleteSavingsGoal(String goalId);
}
