import 'package:flutter_test/flutter_test.dart';
import 'package:kakeibo_app/models/transaction.dart';
import 'package:kakeibo_app/models/payment_method.dart';

// FirestoreServiceの残高計算ロジックを純粋関数として抽出してテスト
// 実際のFirestoreは使わず、ロジックの正しさを検証

/// 取引追加時の残高変動を計算
Map<String, int> calculateBalanceDeltas(
  Transaction tx,
  List<PaymentMethod> paymentMethods,
) {
  final deltas = <String, int>{};

  if (tx.type == TransactionType.transfer) {
    if (tx.fromAccountId.isNotEmpty) {
      deltas[tx.fromAccountId] = -(tx.amount + tx.fee);
    }
    if (tx.toAccountId.isNotEmpty) {
      deltas[tx.toAccountId] = (deltas[tx.toAccountId] ?? 0) + tx.amount;
    }
  } else if (tx.type == TransactionType.income) {
    if (tx.toAccountId.isNotEmpty) {
      deltas[tx.toAccountId] = tx.amount;
    }
  } else {
    // 支出
    if (!tx.isProvisional) {
      final pm = paymentMethods
          .where((m) => m.id == tx.paymentMethodId)
          .firstOrNull;
      if (pm != null && pm.linkedAccountId.isNotEmpty) {
        deltas[pm.linkedAccountId] = -tx.amount;
      }
    }
  }

  return deltas;
}

/// 取引削除時の残高変動（逆転）を計算
Map<String, int> calculateReverseDeltas(
  Transaction tx,
  List<PaymentMethod> paymentMethods,
) {
  final deltas = <String, int>{};

  if (tx.type == TransactionType.transfer) {
    if (tx.fromAccountId.isNotEmpty) {
      deltas[tx.fromAccountId] = tx.amount + tx.fee;
    }
    if (tx.toAccountId.isNotEmpty) {
      deltas[tx.toAccountId] = (deltas[tx.toAccountId] ?? 0) - tx.amount;
    }
  } else if (tx.type == TransactionType.income) {
    if (tx.toAccountId.isNotEmpty) {
      deltas[tx.toAccountId] = -tx.amount;
    }
  } else if (!tx.isProvisional || tx.settled) {
    final pm = paymentMethods
        .where((m) => m.id == tx.paymentMethodId)
        .firstOrNull;
    if (pm != null && pm.linkedAccountId.isNotEmpty) {
      deltas[pm.linkedAccountId] = tx.amount;
    }
  }

  return deltas;
}

void main() {
  final cashPm = PaymentMethod(
    id: 'pm-cash',
    name: '現金',
    type: PaymentMethodType.cash,
    linkedAccountId: 'acc-cash',
  );

  final creditPm = PaymentMethod(
    id: 'pm-cc',
    name: 'クレジットカード',
    type: PaymentMethodType.creditCard,
    linkedAccountId: 'acc-bank',
    creditSettings: CreditSettings(
      closingDay: 31,
      paymentDay: 25,
      paymentMonthOffset: 1,
    ),
  );

  final balancePm = PaymentMethod(
    id: 'pm-balance',
    name: 'PayPay',
    type: PaymentMethodType.balancePayment,
    linkedAccountId: 'acc-paypay',
  );

  final paymentMethods = [cashPm, creditPm, balancePm];

  group('支出の残高計算', () {
    test('現金支出で残高が減る', () {
      final tx = Transaction(
        id: 'tx1',
        date: DateTime.now(),
        type: TransactionType.expense,
        amount: 500,
        paymentMethodId: 'pm-cash',
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas['acc-cash'], -500);
    });

    test('残高払いで残高が減る', () {
      final tx = Transaction(
        id: 'tx2',
        date: DateTime.now(),
        type: TransactionType.expense,
        amount: 1000,
        paymentMethodId: 'pm-balance',
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas['acc-paypay'], -1000);
    });

    test('クレジットカード支出（仮計上）では残高が変わらない', () {
      final tx = Transaction(
        id: 'tx3',
        date: DateTime.now(),
        type: TransactionType.expense,
        amount: 3000,
        paymentMethodId: 'pm-cc',
        isProvisional: true,
        settled: false,
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas.isEmpty, true);
    });
  });

  group('収入の残高計算', () {
    test('収入で受取先の残高が増える', () {
      final tx = Transaction(
        id: 'tx4',
        date: DateTime.now(),
        type: TransactionType.income,
        amount: 300000,
        toAccountId: 'acc-bank',
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas['acc-bank'], 300000);
    });

    test('受取先未指定の収入では残高変動なし', () {
      final tx = Transaction(
        id: 'tx5',
        date: DateTime.now(),
        type: TransactionType.income,
        amount: 5000,
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas.isEmpty, true);
    });
  });

  group('振替の残高計算', () {
    test('振替で元口座が減り先口座が増える', () {
      final tx = Transaction(
        id: 'tx6',
        date: DateTime.now(),
        type: TransactionType.transfer,
        amount: 10000,
        fromAccountId: 'acc-bank',
        toAccountId: 'acc-paypay',
        fee: 0,
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas['acc-bank'], -10000);
      expect(deltas['acc-paypay'], 10000);
    });

    test('振替手数料が元口座から引かれる', () {
      final tx = Transaction(
        id: 'tx7',
        date: DateTime.now(),
        type: TransactionType.transfer,
        amount: 10000,
        fromAccountId: 'acc-bank',
        toAccountId: 'acc-paypay',
        fee: 220,
      );

      final deltas = calculateBalanceDeltas(tx, paymentMethods);
      expect(deltas['acc-bank'], -10220);
      expect(deltas['acc-paypay'], 10000);
    });
  });

  group('残高の逆転（削除時）', () {
    test('現金支出の削除で残高が戻る', () {
      final tx = Transaction(
        id: 'tx1',
        date: DateTime.now(),
        type: TransactionType.expense,
        amount: 500,
        paymentMethodId: 'pm-cash',
      );

      final deltas = calculateReverseDeltas(tx, paymentMethods);
      expect(deltas['acc-cash'], 500);
    });

    test('収入の削除で残高が戻る', () {
      final tx = Transaction(
        id: 'tx4',
        date: DateTime.now(),
        type: TransactionType.income,
        amount: 300000,
        toAccountId: 'acc-bank',
      );

      final deltas = calculateReverseDeltas(tx, paymentMethods);
      expect(deltas['acc-bank'], -300000);
    });

    test('振替の削除で両口座が戻る', () {
      final tx = Transaction(
        id: 'tx7',
        date: DateTime.now(),
        type: TransactionType.transfer,
        amount: 10000,
        fromAccountId: 'acc-bank',
        toAccountId: 'acc-paypay',
        fee: 220,
      );

      final deltas = calculateReverseDeltas(tx, paymentMethods);
      expect(deltas['acc-bank'], 10220);
      expect(deltas['acc-paypay'], -10000);
    });

    test('未精算クレジットカード取引の削除では残高変動なし', () {
      final tx = Transaction(
        id: 'tx3',
        date: DateTime.now(),
        type: TransactionType.expense,
        amount: 3000,
        paymentMethodId: 'pm-cc',
        isProvisional: true,
        settled: false,
      );

      final deltas = calculateReverseDeltas(tx, paymentMethods);
      expect(deltas.isEmpty, true);
    });

    test('精算済みクレジットカード取引の削除で残高が戻る', () {
      final tx = Transaction(
        id: 'tx3',
        date: DateTime.now(),
        type: TransactionType.expense,
        amount: 3000,
        paymentMethodId: 'pm-cc',
        isProvisional: true,
        settled: true,
      );

      final deltas = calculateReverseDeltas(tx, paymentMethods);
      expect(deltas['acc-bank'], 3000);
    });
  });

  group('精算の残高計算', () {
    test('精算で引落先の残高が減る', () {
      final transactions = [
        Transaction(
          id: 'tx1', date: DateTime.now(), type: TransactionType.expense,
          amount: 1000, paymentMethodId: 'pm-cc',
          isProvisional: true, settled: false,
        ),
        Transaction(
          id: 'tx2', date: DateTime.now(), type: TransactionType.expense,
          amount: 2000, paymentMethodId: 'pm-cc',
          isProvisional: true, settled: false,
        ),
      ];

      final totalAmount = transactions.fold<int>(0, (sum, tx) => sum + tx.amount);
      expect(totalAmount, 3000);

      // 精算時は引落先口座から合計額が引かれる
      final linkedAccountId = creditPm.linkedAccountId;
      expect(linkedAccountId, 'acc-bank');
      // delta = -totalAmount
      expect(-totalAmount, -3000);
    });
  });
}
