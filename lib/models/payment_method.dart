import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethodType {
  cash,
  creditCard,
  balancePayment,
  other,
}

class CreditSettings {
  final int closingDay;
  final int paymentDay;
  final int paymentMonthOffset;

  CreditSettings({
    required this.closingDay,
    required this.paymentDay,
    required this.paymentMonthOffset,
  });

  factory CreditSettings.fromMap(Map<String, dynamic> map) {
    return CreditSettings(
      closingDay: (map['closingDay'] ?? 31).toInt(),
      paymentDay: (map['paymentDay'] ?? 25).toInt(),
      paymentMonthOffset: (map['paymentMonthOffset'] ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'closingDay': closingDay,
      'paymentDay': paymentDay,
      'paymentMonthOffset': paymentMonthOffset,
    };
  }
}

class PaymentMethod {
  final String id;
  final String name;
  final PaymentMethodType type;
  final String linkedAccountId;
  final CreditSettings? creditSettings;
  final int sortOrder;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    required this.linkedAccountId,
    this.creditSettings,
    this.sortOrder = 0,
  });

  bool get isCreditCard => type == PaymentMethodType.creditCard;

  factory PaymentMethod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeStr = data['type'] ?? 'cash';
    PaymentMethodType type;
    switch (typeStr) {
      case 'credit_card':
        type = PaymentMethodType.creditCard;
        break;
      case 'balance_payment':
        type = PaymentMethodType.balancePayment;
        break;
      case 'other':
        type = PaymentMethodType.other;
        break;
      default:
        type = PaymentMethodType.cash;
    }

    return PaymentMethod(
      id: doc.id,
      name: data['name'] ?? '',
      type: type,
      linkedAccountId: data['linkedAccountId'] ?? '',
      creditSettings: data['creditSettings'] != null
          ? CreditSettings.fromMap(data['creditSettings'])
          : null,
      sortOrder: (data['sortOrder'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    String typeStr;
    switch (type) {
      case PaymentMethodType.creditCard:
        typeStr = 'credit_card';
        break;
      case PaymentMethodType.balancePayment:
        typeStr = 'balance_payment';
        break;
      case PaymentMethodType.other:
        typeStr = 'other';
        break;
      default:
        typeStr = 'cash';
    }

    return {
      'name': name,
      'type': typeStr,
      'linkedAccountId': linkedAccountId,
      'creditSettings': creditSettings?.toMap(),
      'sortOrder': sortOrder,
    };
  }

  String get typeLabel {
    switch (type) {
      case PaymentMethodType.cash:
        return '現金・即時';
      case PaymentMethodType.creditCard:
        return 'クレジットカード';
      case PaymentMethodType.balancePayment:
        return '残高払い';
      case PaymentMethodType.other:
        return 'その他';
    }
  }
}
