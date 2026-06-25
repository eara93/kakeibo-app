import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kakeibo_app/models/transaction.dart' as app;

void main() {
  group('Transaction モデル', () {
    test('支出の toFirestore が正しい', () {
      final tx = app.Transaction(
        id: 'tx1',
        date: DateTime(2026, 6, 25),
        type: app.TransactionType.expense,
        category: '食費',
        itemName: 'コンビニ',
        amount: 500,
        paymentMethodId: 'pm1',
      );

      final map = tx.toFirestore();
      expect(map['type'], 'expense');
      expect(map['category'], '食費');
      expect(map['itemName'], 'コンビニ');
      expect(map['amount'], 500);
      expect(map['paymentMethodId'], 'pm1');
      expect(map['isProvisional'], false);
      expect(map['settled'], true);
    });

    test('収入の toFirestore が正しい', () {
      final tx = app.Transaction(
        id: 'tx2',
        date: DateTime(2026, 6, 25),
        type: app.TransactionType.income,
        category: '給与',
        itemName: '月給',
        amount: 300000,
        toAccountId: 'acc1',
      );

      final map = tx.toFirestore();
      expect(map['type'], 'income');
      expect(map['amount'], 300000);
      expect(map['toAccountId'], 'acc1');
    });

    test('振替の toFirestore が正しい', () {
      final tx = app.Transaction(
        id: 'tx3',
        date: DateTime(2026, 6, 25),
        type: app.TransactionType.transfer,
        amount: 10000,
        fromAccountId: 'acc1',
        toAccountId: 'acc2',
        fee: 220,
      );

      final map = tx.toFirestore();
      expect(map['type'], 'transfer');
      expect(map['fromAccountId'], 'acc1');
      expect(map['toAccountId'], 'acc2');
      expect(map['fee'], 220);
    });

    test('fromFirestore で正しくデシリアライズされる', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('transactions').doc('tx1').set({
        'date': Timestamp.fromDate(DateTime(2026, 6, 25)),
        'type': 'expense',
        'category': '交通費',
        'itemName': '電車',
        'amount': 320,
        'paymentMethodId': 'pm1',
        'fromAccountId': '',
        'toAccountId': '',
        'fee': 0,
        'isProvisional': false,
        'settled': true,
        'createdAt': Timestamp.now(),
      });

      final doc = await firestore.collection('transactions').doc('tx1').get();
      final tx = app.Transaction.fromFirestore(doc);

      expect(tx.id, 'tx1');
      expect(tx.type, app.TransactionType.expense);
      expect(tx.category, '交通費');
      expect(tx.itemName, '電車');
      expect(tx.amount, 320);
      expect(tx.isProvisional, false);
      expect(tx.settled, true);
    });

    test('クレジットカード取引（仮計上）のデシリアライズ', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('transactions').doc('tx2').set({
        'date': Timestamp.fromDate(DateTime(2026, 6, 20)),
        'type': 'expense',
        'category': '食費',
        'itemName': 'レストラン',
        'amount': 3000,
        'paymentMethodId': 'cc1',
        'fromAccountId': '',
        'toAccountId': '',
        'fee': 0,
        'isProvisional': true,
        'settled': false,
        'createdAt': Timestamp.now(),
      });

      final doc = await firestore.collection('transactions').doc('tx2').get();
      final tx = app.Transaction.fromFirestore(doc);

      expect(tx.isProvisional, true);
      expect(tx.settled, false);
    });

    test('copyWith で部分更新できる', () {
      final original = app.Transaction(
        id: 'tx1',
        date: DateTime(2026, 6, 25),
        type: app.TransactionType.expense,
        category: '食費',
        amount: 500,
      );

      final updated = original.copyWith(
        amount: 1000,
        isProvisional: true,
        settled: false,
      );

      expect(updated.amount, 1000);
      expect(updated.isProvisional, true);
      expect(updated.settled, false);
      expect(updated.category, '食費');
      expect(updated.id, 'tx1');
    });

    test('typeLabel が正しい', () {
      expect(
        app.Transaction(id: '', date: DateTime.now(), type: app.TransactionType.income, amount: 0).typeLabel,
        '収入',
      );
      expect(
        app.Transaction(id: '', date: DateTime.now(), type: app.TransactionType.expense, amount: 0).typeLabel,
        '支出',
      );
      expect(
        app.Transaction(id: '', date: DateTime.now(), type: app.TransactionType.transfer, amount: 0).typeLabel,
        '振替',
      );
    });

    test('未知の type は expense にフォールバックする', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('transactions').doc('tx3').set({
        'date': Timestamp.now(),
        'type': 'unknown_type',
        'category': '',
        'itemName': '',
        'amount': 100,
        'paymentMethodId': '',
        'fromAccountId': '',
        'toAccountId': '',
        'fee': 0,
        'isProvisional': false,
        'settled': true,
        'createdAt': Timestamp.now(),
      });

      final doc = await firestore.collection('transactions').doc('tx3').get();
      final tx = app.Transaction.fromFirestore(doc);
      expect(tx.type, app.TransactionType.expense);
    });
  });
}
