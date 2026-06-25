import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kakeibo_app/models/favorite.dart';
import 'package:kakeibo_app/models/transaction.dart';

void main() {
  group('Favorite モデル', () {
    test('toFirestore で正しくシリアライズされる', () {
      final fav = Favorite(
        id: 'fav1',
        name: 'コンビニ弁当',
        type: TransactionType.expense,
        category: '食費',
        itemName: 'コンビニ',
        amount: 500,
        paymentMethodId: 'pm1',
      );

      final map = fav.toFirestore();
      expect(map['name'], 'コンビニ弁当');
      expect(map['type'], 'expense');
      expect(map['category'], '食費');
      expect(map['itemName'], 'コンビニ');
      expect(map['amount'], 500);
      expect(map['paymentMethodId'], 'pm1');
    });

    test('fromFirestore で正しくデシリアライズされる', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('favorites').doc('fav1').set({
        'name': '給料',
        'type': 'income',
        'category': '給与',
        'itemName': '月給',
        'amount': 300000,
        'paymentMethodId': '',
        'toAccountId': 'acc1',
        'fromAccountId': '',
        'fee': 0,
        'createdAt': Timestamp.now(),
      });

      final doc = await firestore.collection('favorites').doc('fav1').get();
      final fav = Favorite.fromFirestore(doc);

      expect(fav.id, 'fav1');
      expect(fav.name, '給料');
      expect(fav.type, TransactionType.income);
      expect(fav.category, '給与');
      expect(fav.amount, 300000);
      expect(fav.toAccountId, 'acc1');
    });

    test('金額0のお気に入りが保存できる', () {
      final fav = Favorite(
        id: '',
        name: 'テンプレート',
        type: TransactionType.expense,
        category: '食費',
        amount: 0,
      );

      final map = fav.toFirestore();
      expect(map['amount'], 0);
    });

    test('振替のお気に入りが正しく保存される', () {
      final fav = Favorite(
        id: '',
        name: '口座間移動',
        type: TransactionType.transfer,
        fromAccountId: 'acc1',
        toAccountId: 'acc2',
        amount: 10000,
        fee: 220,
      );

      final map = fav.toFirestore();
      expect(map['type'], 'transfer');
      expect(map['fromAccountId'], 'acc1');
      expect(map['toAccountId'], 'acc2');
      expect(map['fee'], 220);
    });
  });
}
