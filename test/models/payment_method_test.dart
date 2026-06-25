import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kakeibo_app/models/payment_method.dart';

void main() {
  group('PaymentMethod モデル', () {
    test('toFirestore で正しくシリアライズされる', () {
      final method = PaymentMethod(
        id: 'pm1',
        name: '現金',
        type: PaymentMethodType.cash,
        linkedAccountId: 'acc1',
      );

      final map = method.toFirestore();
      expect(map['name'], '現金');
      expect(map['type'], 'cash');
      expect(map['linkedAccountId'], 'acc1');
      expect(map['creditSettings'], isNull);
    });

    test('クレジットカードの設定がシリアライズされる', () {
      final method = PaymentMethod(
        id: 'pm2',
        name: 'VISA',
        type: PaymentMethodType.creditCard,
        linkedAccountId: 'acc1',
        creditSettings: CreditSettings(
          closingDay: 15,
          paymentDay: 10,
          paymentMonthOffset: 2,
        ),
      );

      final map = method.toFirestore();
      expect(map['type'], 'credit_card');
      expect(map['creditSettings']['closingDay'], 15);
      expect(map['creditSettings']['paymentDay'], 10);
      expect(map['creditSettings']['paymentMonthOffset'], 2);
    });

    test('fromFirestore で正しくデシリアライズされる', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('methods').doc('pm1').set({
        'name': 'PayPay',
        'type': 'balance_payment',
        'linkedAccountId': 'acc2',
        'sortOrder': 0,
      });

      final doc = await firestore.collection('methods').doc('pm1').get();
      final method = PaymentMethod.fromFirestore(doc);

      expect(method.name, 'PayPay');
      expect(method.type, PaymentMethodType.balancePayment);
      expect(method.linkedAccountId, 'acc2');
      expect(method.isCreditCard, false);
    });

    test('クレジットカードの設定がデシリアライズされる', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('methods').doc('pm2').set({
        'name': 'JCB',
        'type': 'credit_card',
        'linkedAccountId': 'acc1',
        'creditSettings': {
          'closingDay': 31,
          'paymentDay': 25,
          'paymentMonthOffset': 1,
        },
        'sortOrder': 0,
      });

      final doc = await firestore.collection('methods').doc('pm2').get();
      final method = PaymentMethod.fromFirestore(doc);

      expect(method.isCreditCard, true);
      expect(method.creditSettings, isNotNull);
      expect(method.creditSettings!.closingDay, 31);
      expect(method.creditSettings!.paymentDay, 25);
      expect(method.creditSettings!.paymentMonthOffset, 1);
    });

    test('全 PaymentMethodType が正しく変換される', () async {
      final firestore = FakeFirebaseFirestore();
      final types = {
        PaymentMethodType.cash: 'cash',
        PaymentMethodType.creditCard: 'credit_card',
        PaymentMethodType.balancePayment: 'balance_payment',
        PaymentMethodType.other: 'other',
      };

      for (final entry in types.entries) {
        final method = PaymentMethod(
          id: '', name: 'test', type: entry.key, linkedAccountId: '',
        );
        expect(method.toFirestore()['type'], entry.value);

        await firestore.collection('methods').doc(entry.value).set({
          'name': 'test', 'type': entry.value, 'linkedAccountId': '', 'sortOrder': 0,
        });
        final doc = await firestore.collection('methods').doc(entry.value).get();
        expect(PaymentMethod.fromFirestore(doc).type, entry.key);
      }
    });

    test('typeLabel が正しい', () {
      expect(
        PaymentMethod(id: '', name: '', type: PaymentMethodType.cash, linkedAccountId: '').typeLabel,
        '現金・即時',
      );
      expect(
        PaymentMethod(id: '', name: '', type: PaymentMethodType.creditCard, linkedAccountId: '').typeLabel,
        'クレジットカード',
      );
      expect(
        PaymentMethod(id: '', name: '', type: PaymentMethodType.balancePayment, linkedAccountId: '').typeLabel,
        '残高払い',
      );
      expect(
        PaymentMethod(id: '', name: '', type: PaymentMethodType.other, linkedAccountId: '').typeLabel,
        'その他',
      );
    });

    test('未知の type は cash にフォールバックする', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('methods').doc('pm3').set({
        'name': 'unknown',
        'type': 'something_new',
        'linkedAccountId': '',
        'sortOrder': 0,
      });

      final doc = await firestore.collection('methods').doc('pm3').get();
      final method = PaymentMethod.fromFirestore(doc);
      expect(method.type, PaymentMethodType.cash);
    });
  });
}
