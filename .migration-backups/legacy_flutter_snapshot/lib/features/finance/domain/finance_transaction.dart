import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

const incomeCategories = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'];
const expenseCategories = [
  'Housing',
  'Food',
  'Transport',
  'Entertainment',
  'Health',
  'Shopping',
  'Other',
];

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  factory FinanceTransaction.fromFirestore(String id, Map<String, dynamic> data) {
    return FinanceTransaction(
      id: id,
      type: TransactionType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'Other',
      note: data['note'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date),
    };
  }
}
