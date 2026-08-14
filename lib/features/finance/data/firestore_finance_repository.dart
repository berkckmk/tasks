import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/query_limits.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/savings_goal.dart';

class FirestoreFinanceRepository implements FinanceRepository {
  FirestoreFinanceRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('users').doc(_uid).collection('finance_transactions');

  CollectionReference<Map<String, dynamic>> get _savingsGoalsRef =>
      _firestore.collection('users').doc(_uid).collection('savings_goals');

  @override
  Stream<List<FinanceTransaction>> watchTransactions() {
    return _transactionsRef.orderBy('date', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => FinanceTransaction.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
  }) async {
    await _transactionsRef.add({
      ...FinanceTransaction(
        id: '',
        type: type,
        amount: amount,
        category: category,
        note: note,
        date: date,
      ).toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    await _transactionsRef.doc(transactionId).delete();
  }

  @override
  Stream<List<SavingsGoal>> watchSavingsGoals() {
    return _savingsGoalsRef.orderBy('createdAt', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => SavingsGoal.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> saveSavingsGoal({
    required String? id,
    required String title,
    required double targetAmount,
    required double currentAmount,
    required DateTime? targetDate,
  }) async {
    final data = SavingsGoal(
      id: id ?? '',
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
    ).toFirestore();

    if (id == null) {
      await _savingsGoalsRef.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _savingsGoalsRef.doc(id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteSavingsGoal(String goalId) async {
    await _savingsGoalsRef.doc(goalId).delete();
  }
}
