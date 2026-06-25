import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  income,
  expense,
  transfer,
}

class Transaction {
  final String id;
  final DateTime date;
  final TransactionType type;
  final String category;
  final String itemName;
  final int amount;
  final String paymentMethodId;
  final String fromAccountId;
  final String toAccountId;
  final int fee;
  final bool isProvisional;
  final bool settled;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.date,
    required this.type,
    this.category = '',
    this.itemName = '',
    required this.amount,
    this.paymentMethodId = '',
    this.fromAccountId = '',
    this.toAccountId = '',
    this.fee = 0,
    this.isProvisional = false,
    this.settled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    TransactionType type;
    switch (data['type'] ?? 'expense') {
      case 'income':
        type = TransactionType.income;
        break;
      case 'transfer':
        type = TransactionType.transfer;
        break;
      default:
        type = TransactionType.expense;
    }

    return Transaction(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: type,
      category: data['category'] ?? '',
      itemName: data['itemName'] ?? '',
      amount: (data['amount'] ?? 0).toInt(),
      paymentMethodId: data['paymentMethodId'] ?? '',
      fromAccountId: data['fromAccountId'] ?? '',
      toAccountId: data['toAccountId'] ?? '',
      fee: (data['fee'] ?? 0).toInt(),
      isProvisional: data['isProvisional'] ?? false,
      settled: data['settled'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    String typeStr;
    switch (type) {
      case TransactionType.income:
        typeStr = 'income';
        break;
      case TransactionType.transfer:
        typeStr = 'transfer';
        break;
      default:
        typeStr = 'expense';
    }

    return {
      'date': Timestamp.fromDate(date),
      'type': typeStr,
      'category': category,
      'itemName': itemName,
      'amount': amount,
      'paymentMethodId': paymentMethodId,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'fee': fee,
      'isProvisional': isProvisional,
      'settled': settled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Transaction copyWith({
    String? id,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? itemName,
    int? amount,
    String? paymentMethodId,
    String? fromAccountId,
    String? toAccountId,
    int? fee,
    bool? isProvisional,
    bool? settled,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      itemName: itemName ?? this.itemName,
      amount: amount ?? this.amount,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      fee: fee ?? this.fee,
      isProvisional: isProvisional ?? this.isProvisional,
      settled: settled ?? this.settled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get typeLabel {
    switch (type) {
      case TransactionType.income:
        return '収入';
      case TransactionType.expense:
        return '支出';
      case TransactionType.transfer:
        return '振替';
    }
  }
}
