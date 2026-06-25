import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String name;
  final int balance;
  final int sortOrder;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Account.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Account(
      id: doc.id,
      name: data['name'] ?? '',
      balance: (data['balance'] ?? 0).toInt(),
      sortOrder: (data['sortOrder'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'balance': balance,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    int? balance,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
