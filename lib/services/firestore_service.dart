import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/payment_method.dart';
import '../models/transaction.dart' as app;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _accountsRef =>
      _db.collection('users').doc(_uid).collection('accounts');

  CollectionReference get _categoriesRef =>
      _db.collection('users').doc(_uid).collection('categories');

  CollectionReference get _paymentMethodsRef =>
      _db.collection('users').doc(_uid).collection('paymentMethods');

  CollectionReference get _transactionsRef =>
      _db.collection('users').doc(_uid).collection('transactions');

  DocumentReference get _settingsRef =>
      _db.collection('users').doc(_uid);

  // ===== 口座 =====

  Stream<List<Account>> watchAccounts() {
    return _accountsRef.orderBy('sortOrder').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList());
  }

  Future<List<Account>> getAccounts() async {
    final snapshot = await _accountsRef.orderBy('sortOrder').get();
    return snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList();
  }

  Future<Account?> getAccount(String id) async {
    final doc = await _accountsRef.doc(id).get();
    if (!doc.exists) return null;
    return Account.fromFirestore(doc);
  }

  Future<void> addAccount(Account account) async {
    await _accountsRef.add(account.toFirestore());
  }

  Future<void> updateAccount(Account account) async {
    await _accountsRef.doc(account.id).update(account.toFirestore());
  }

  Future<void> deleteAccount(String id) async {
    await _accountsRef.doc(id).delete();
  }

  Future<void> updateAccountBalance(String accountId, int delta) async {
    await _accountsRef.doc(accountId).update({
      'balance': FieldValue.increment(delta),
    });
  }

  // ===== カテゴリ =====

  Stream<List<Category>> watchCategories() {
    return _categoriesRef.orderBy('sortOrder').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList());
  }

  Future<List<Category>> getCategories() async {
    final snapshot = await _categoriesRef.orderBy('sortOrder').get();
    return snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
  }

  Future<void> addCategory(Category category) async {
    await _categoriesRef.add(category.toFirestore());
  }

  Future<void> updateCategory(Category category) async {
    await _categoriesRef.doc(category.id).update(category.toFirestore());
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesRef.doc(id).delete();
  }

  // ===== 支払方法 =====

  Stream<List<PaymentMethod>> watchPaymentMethods() {
    return _paymentMethodsRef.orderBy('sortOrder').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => PaymentMethod.fromFirestore(doc))
            .toList());
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final snapshot = await _paymentMethodsRef.orderBy('sortOrder').get();
    return snapshot.docs
        .map((doc) => PaymentMethod.fromFirestore(doc))
        .toList();
  }

  Future<PaymentMethod?> getPaymentMethod(String id) async {
    final doc = await _paymentMethodsRef.doc(id).get();
    if (!doc.exists) return null;
    return PaymentMethod.fromFirestore(doc);
  }

  Future<void> addPaymentMethod(PaymentMethod method) async {
    await _paymentMethodsRef.add(method.toFirestore());
  }

  Future<void> updatePaymentMethod(PaymentMethod method) async {
    await _paymentMethodsRef.doc(method.id).update(method.toFirestore());
  }

  Future<void> deletePaymentMethod(String id) async {
    await _paymentMethodsRef.doc(id).delete();
  }

  // ===== 取引 =====

  Stream<List<app.Transaction>> watchTransactions() {
    return _transactionsRef
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app.Transaction.fromFirestore(doc))
            .toList());
  }

  Future<List<app.Transaction>> getTransactions() async {
    final snapshot =
        await _transactionsRef.orderBy('date', descending: true).get();
    return snapshot.docs
        .map((doc) => app.Transaction.fromFirestore(doc))
        .toList();
  }

  Future<app.Transaction?> getTransaction(String id) async {
    final doc = await _transactionsRef.doc(id).get();
    if (!doc.exists) return null;
    return app.Transaction.fromFirestore(doc);
  }

  Future<void> addTransaction(app.Transaction transaction,
      List<PaymentMethod> paymentMethods) async {
    final batch = _db.batch();
    final docRef = _transactionsRef.doc();

    bool isProvisional = false;
    if (transaction.type != app.TransactionType.transfer &&
        transaction.paymentMethodId.isNotEmpty) {
      final pm = paymentMethods
          .where((m) => m.id == transaction.paymentMethodId)
          .firstOrNull;
      if (pm != null && pm.isCreditCard) {
        isProvisional = true;
      }
    }

    final txData = transaction
        .copyWith(isProvisional: isProvisional, settled: !isProvisional)
        .toFirestore();
    batch.set(docRef, txData);

    // 残高更新
    if (transaction.type == app.TransactionType.transfer) {
      if (transaction.fromAccountId.isNotEmpty) {
        batch.update(_accountsRef.doc(transaction.fromAccountId), {
          'balance':
              FieldValue.increment(-(transaction.amount + transaction.fee)),
        });
      }
      if (transaction.toAccountId.isNotEmpty) {
        batch.update(_accountsRef.doc(transaction.toAccountId), {
          'balance': FieldValue.increment(transaction.amount),
        });
      }
    } else if (!isProvisional) {
      final pm = paymentMethods
          .where((m) => m.id == transaction.paymentMethodId)
          .firstOrNull;
      if (pm != null && pm.linkedAccountId.isNotEmpty) {
        final delta = transaction.type == app.TransactionType.income
            ? transaction.amount
            : -transaction.amount;
        batch.update(_accountsRef.doc(pm.linkedAccountId), {
          'balance': FieldValue.increment(delta),
        });
      }
    }

    await batch.commit();
  }

  Future<void> updateTransaction(
    app.Transaction oldTx,
    app.Transaction newTx,
    List<PaymentMethod> paymentMethods,
  ) async {
    final batch = _db.batch();

    // 旧取引の残高影響を逆転
    _reverseBalanceEffect(batch, oldTx, paymentMethods);

    bool isProvisional = false;
    if (newTx.type != app.TransactionType.transfer &&
        newTx.paymentMethodId.isNotEmpty) {
      final pm = paymentMethods
          .where((m) => m.id == newTx.paymentMethodId)
          .firstOrNull;
      if (pm != null && pm.isCreditCard) {
        isProvisional = true;
      }
    }

    final updated =
        newTx.copyWith(isProvisional: isProvisional, settled: !isProvisional);
    batch.update(_transactionsRef.doc(newTx.id), updated.toFirestore());

    // 新取引の残高影響を適用
    _applyBalanceEffect(batch, updated, paymentMethods);

    await batch.commit();
  }

  Future<void> deleteTransaction(
      app.Transaction transaction, List<PaymentMethod> paymentMethods) async {
    final batch = _db.batch();
    batch.delete(_transactionsRef.doc(transaction.id));
    _reverseBalanceEffect(batch, transaction, paymentMethods);
    await batch.commit();
  }

  void _reverseBalanceEffect(WriteBatch batch, app.Transaction tx,
      List<PaymentMethod> paymentMethods) {
    if (tx.type == app.TransactionType.transfer) {
      if (tx.fromAccountId.isNotEmpty) {
        batch.update(_accountsRef.doc(tx.fromAccountId), {
          'balance': FieldValue.increment(tx.amount + tx.fee),
        });
      }
      if (tx.toAccountId.isNotEmpty) {
        batch.update(_accountsRef.doc(tx.toAccountId), {
          'balance': FieldValue.increment(-tx.amount),
        });
      }
    } else if (!tx.isProvisional || tx.settled) {
      final pm = paymentMethods
          .where((m) => m.id == tx.paymentMethodId)
          .firstOrNull;
      if (pm != null && pm.linkedAccountId.isNotEmpty) {
        final delta = tx.type == app.TransactionType.income
            ? -tx.amount
            : tx.amount;
        batch.update(_accountsRef.doc(pm.linkedAccountId), {
          'balance': FieldValue.increment(delta),
        });
      }
    }
  }

  void _applyBalanceEffect(WriteBatch batch, app.Transaction tx,
      List<PaymentMethod> paymentMethods) {
    if (tx.type == app.TransactionType.transfer) {
      if (tx.fromAccountId.isNotEmpty) {
        batch.update(_accountsRef.doc(tx.fromAccountId), {
          'balance': FieldValue.increment(-(tx.amount + tx.fee)),
        });
      }
      if (tx.toAccountId.isNotEmpty) {
        batch.update(_accountsRef.doc(tx.toAccountId), {
          'balance': FieldValue.increment(tx.amount),
        });
      }
    } else if (!tx.isProvisional) {
      final pm = paymentMethods
          .where((m) => m.id == tx.paymentMethodId)
          .firstOrNull;
      if (pm != null && pm.linkedAccountId.isNotEmpty) {
        final delta = tx.type == app.TransactionType.income
            ? tx.amount
            : -tx.amount;
        batch.update(_accountsRef.doc(pm.linkedAccountId), {
          'balance': FieldValue.increment(delta),
        });
      }
    }
  }

  // ===== 精算 =====

  Stream<List<app.Transaction>> watchUnsettledTransactions() {
    return _transactionsRef
        .where('isProvisional', isEqualTo: true)
        .where('settled', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app.Transaction.fromFirestore(doc))
            .toList());
  }

  Future<void> settleTransactions(
      List<app.Transaction> transactions, String linkedAccountId) async {
    final batch = _db.batch();
    int totalAmount = 0;

    for (final tx in transactions) {
      batch.update(_transactionsRef.doc(tx.id), {'settled': true});
      totalAmount += tx.amount;
    }

    batch.update(_accountsRef.doc(linkedAccountId), {
      'balance': FieldValue.increment(-totalAmount),
    });

    await batch.commit();
  }

  // ===== 設定 =====

  Future<List<String>> getDashboardOrder() async {
    final doc = await _settingsRef.get();
    if (!doc.exists) return defaultDashboardOrder;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || data['dashboardOrder'] == null) {
      return defaultDashboardOrder;
    }
    return List<String>.from(data['dashboardOrder']);
  }

  Future<void> saveDashboardOrder(List<String> order) async {
    await _settingsRef.set({
      'dashboardOrder': order,
    }, SetOptions(merge: true));
  }

  static const defaultDashboardOrder = [
    'assets',
    'yearly_summary',
    'monthly_summary',
    'account_balances',
    'expense_chart',
    'recent_transactions',
  ];
}
