import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetType {
  bankAccount,
  balance,
  cash,
}

class Account {
  final String id;
  final String name;
  final int balance;
  final AssetType assetType;
  final int sortOrder;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.assetType = AssetType.bankAccount,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Account.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    AssetType assetType;
    switch (data['assetType'] ?? 'bank_account') {
      case 'balance':
        assetType = AssetType.balance;
        break;
      case 'cash':
        assetType = AssetType.cash;
        break;
      default:
        assetType = AssetType.bankAccount;
    }

    return Account(
      id: doc.id,
      name: data['name'] ?? '',
      balance: (data['balance'] ?? 0).toInt(),
      assetType: assetType,
      sortOrder: (data['sortOrder'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    String assetTypeStr;
    switch (assetType) {
      case AssetType.balance:
        assetTypeStr = 'balance';
        break;
      case AssetType.cash:
        assetTypeStr = 'cash';
        break;
      default:
        assetTypeStr = 'bank_account';
    }

    return {
      'name': name,
      'balance': balance,
      'assetType': assetTypeStr,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    int? balance,
    AssetType? assetType,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      assetType: assetType ?? this.assetType,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get assetTypeLabel {
    switch (assetType) {
      case AssetType.bankAccount:
        return '口座';
      case AssetType.balance:
        return '残高';
      case AssetType.cash:
        return '現金';
    }
  }
}
