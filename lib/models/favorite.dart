import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction.dart';

class Favorite {
  final String id;
  final String name;
  final TransactionType type;
  final String category;
  final String itemName;
  final int amount;
  final String paymentMethodId;
  final String toAccountId;
  final String fromAccountId;
  final int fee;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.name,
    required this.type,
    this.category = '',
    this.itemName = '',
    this.amount = 0,
    this.paymentMethodId = '',
    this.toAccountId = '',
    this.fromAccountId = '',
    this.fee = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Favorite.fromFirestore(DocumentSnapshot doc) {
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

    return Favorite(
      id: doc.id,
      name: data['name'] ?? '',
      type: type,
      category: data['category'] ?? '',
      itemName: data['itemName'] ?? '',
      amount: (data['amount'] ?? 0).toInt(),
      paymentMethodId: data['paymentMethodId'] ?? '',
      toAccountId: data['toAccountId'] ?? '',
      fromAccountId: data['fromAccountId'] ?? '',
      fee: (data['fee'] ?? 0).toInt(),
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
      'name': name,
      'type': typeStr,
      'category': category,
      'itemName': itemName,
      'amount': amount,
      'paymentMethodId': paymentMethodId,
      'toAccountId': toAccountId,
      'fromAccountId': fromAccountId,
      'fee': fee,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
