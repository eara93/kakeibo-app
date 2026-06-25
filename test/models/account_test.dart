import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kakeibo_app/models/account.dart';

void main() {
  group('Account モデル', () {
    test('toFirestore で正しくシリアライズされる', () {
      final account = Account(
        id: 'test-id',
        name: '銀行口座',
        balance: 10000,
        assetType: AssetType.bankAccount,
        sortOrder: 1,
      );

      final map = account.toFirestore();
      expect(map['name'], '銀行口座');
      expect(map['balance'], 10000);
      expect(map['assetType'], 'bank_account');
      expect(map['sortOrder'], 1);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('fromFirestore で正しくデシリアライズされる', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('accounts').doc('acc1').set({
        'name': 'PayPay',
        'balance': 5000,
        'assetType': 'balance',
        'sortOrder': 2,
        'createdAt': Timestamp.now(),
      });

      final doc = await firestore.collection('accounts').doc('acc1').get();
      final account = Account.fromFirestore(doc);

      expect(account.id, 'acc1');
      expect(account.name, 'PayPay');
      expect(account.balance, 5000);
      expect(account.assetType, AssetType.balance);
      expect(account.sortOrder, 2);
    });

    test('assetType が未設定の場合 bankAccount になる', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('accounts').doc('acc2').set({
        'name': '古いデータ',
        'balance': 1000,
        'sortOrder': 0,
        'createdAt': Timestamp.now(),
      });

      final doc = await firestore.collection('accounts').doc('acc2').get();
      final account = Account.fromFirestore(doc);

      expect(account.assetType, AssetType.bankAccount);
    });

    test('全 AssetType が正しくシリアライズ/デシリアライズされる', () async {
      final firestore = FakeFirebaseFirestore();

      final types = {
        AssetType.bankAccount: 'bank_account',
        AssetType.balance: 'balance',
        AssetType.cash: 'cash',
      };

      for (final entry in types.entries) {
        final account = Account(
          id: '',
          name: 'test',
          balance: 0,
          assetType: entry.key,
        );
        expect(account.toFirestore()['assetType'], entry.value);

        await firestore
            .collection('accounts')
            .doc(entry.value)
            .set({'name': 'test', 'balance': 0, 'assetType': entry.value, 'sortOrder': 0, 'createdAt': Timestamp.now()});
        final doc =
            await firestore.collection('accounts').doc(entry.value).get();
        expect(Account.fromFirestore(doc).assetType, entry.key);
      }
    });

    test('copyWith で部分更新できる', () {
      final original = Account(
        id: 'id1',
        name: '元の名前',
        balance: 1000,
        assetType: AssetType.cash,
      );

      final updated = original.copyWith(name: '新しい名前', balance: 2000);

      expect(updated.name, '新しい名前');
      expect(updated.balance, 2000);
      expect(updated.id, 'id1');
      expect(updated.assetType, AssetType.cash);
    });

    test('assetTypeLabel が正しい', () {
      expect(
        Account(id: '', name: '', balance: 0, assetType: AssetType.bankAccount)
            .assetTypeLabel,
        '口座',
      );
      expect(
        Account(id: '', name: '', balance: 0, assetType: AssetType.balance)
            .assetTypeLabel,
        '残高',
      );
      expect(
        Account(id: '', name: '', balance: 0, assetType: AssetType.cash)
            .assetTypeLabel,
        '現金',
      );
    });

    test('マイナス残高を保持できる', () {
      final account = Account(id: '', name: 'クレカ', balance: -5000);
      expect(account.balance, -5000);
      expect(account.toFirestore()['balance'], -5000);
    });
  });
}
