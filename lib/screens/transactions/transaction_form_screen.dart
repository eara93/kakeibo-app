import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction.dart' as app;
import '../../models/account.dart';
import '../../models/category.dart';
import '../../models/payment_method.dart';

class TransactionFormScreen extends StatefulWidget {
  final app.Transaction? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _service = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late app.TransactionType _type;
  late DateTime _date;
  String _category = '';
  String _itemName = '';
  int _amount = 0;
  String _paymentMethodId = '';
  String _fromAccountId = '';
  String _toAccountId = '';
  int _fee = 0;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<PaymentMethod> _paymentMethods = [];

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?.type ?? app.TransactionType.expense;
    _date = tx?.date ?? DateTime.now();
    _category = tx?.category ?? '';
    _itemName = tx?.itemName ?? '';
    _amount = tx?.amount ?? 0;
    _paymentMethodId = tx?.paymentMethodId ?? '';
    _fromAccountId = tx?.fromAccountId ?? '';
    _toAccountId = tx?.toAccountId ?? '';
    _fee = tx?.fee ?? 0;
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await _service.getAccounts();
    final categories = await _service.getCategories();
    final paymentMethods = await _service.getPaymentMethods();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _categories = categories;
        _paymentMethods = paymentMethods;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    try {
      final tx = app.Transaction(
        id: widget.transaction?.id ?? '',
        date: _date,
        type: _type,
        category: _category,
        itemName: _itemName,
        amount: _amount,
        paymentMethodId:
            _type == app.TransactionType.expense ? _paymentMethodId : '',
        fromAccountId:
            _type == app.TransactionType.transfer ? _fromAccountId : '',
        toAccountId: _type == app.TransactionType.transfer
            ? _toAccountId
            : _type == app.TransactionType.income
                ? _toAccountId
                : '',
        fee: _type == app.TransactionType.transfer ? _fee : 0,
        createdAt: widget.transaction?.createdAt,
      );

      if (_isEditing) {
        await _service.updateTransaction(
            widget.transaction!, tx, _paymentMethods);
      } else {
        await _service.addTransaction(tx, _paymentMethods);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '取引を更新しました' : '取引を追加しました'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '取引を編集' : '取引を追加'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 種類
                    SegmentedButton<app.TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: app.TransactionType.expense,
                          label: Text('支出'),
                        ),
                        ButtonSegment(
                          value: app.TransactionType.income,
                          label: Text('収入'),
                        ),
                        ButtonSegment(
                          value: app.TransactionType.transfer,
                          label: Text('振替'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                      style: SegmentedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 日付
                    GestureDetector(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '日付',
                          suffixIcon: const Icon(Icons.calendar_today, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: Text(
                          DateFormat('yyyy年M月d日').format(_date),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // カテゴリ
                    DropdownButtonFormField<String>(
                      initialValue: _categories.any((c) => c.name == _category)
                          ? _category
                          : null,
                      decoration: const InputDecoration(labelText: 'カテゴリ'),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c.name, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? ''),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'カテゴリを選択してください' : null,
                    ),
                    const SizedBox(height: 16),

                    // 金額
                    TextFormField(
                      initialValue: _amount > 0 ? _amount.toString() : '',
                      decoration: const InputDecoration(
                        labelText: '金額',
                        prefixText: '¥ ',
                      ),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '金額を入力してください';
                        if (int.tryParse(v) == null || int.parse(v) <= 0) {
                          return '有効な金額を入力してください';
                        }
                        return null;
                      },
                      onSaved: (v) => _amount = int.parse(v!),
                    ),
                    const SizedBox(height: 16),

                    if (_type == app.TransactionType.income) ...[
                      TextFormField(
                        initialValue: _itemName,
                        decoration:
                            const InputDecoration(labelText: '品名・メモ'),
                        style: const TextStyle(fontSize: 17),
                        onSaved: (v) => _itemName = v ?? '',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _accounts.any((a) => a.id == _toAccountId)
                                ? _toAccountId
                                : null,
                        decoration:
                            const InputDecoration(labelText: '受取先'),
                        items: _accounts
                            .map((a) => DropdownMenuItem(
                                value: a.id, child: Text(a.name)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _toAccountId = v ?? ''),
                        validator: (v) =>
                            v == null || v.isEmpty ? '受取先を選択してください' : null,
                      ),
                    ],

                    if (_type == app.TransactionType.expense) ...[
                      TextFormField(
                        initialValue: _itemName,
                        decoration:
                            const InputDecoration(labelText: '品名・メモ'),
                        style: const TextStyle(fontSize: 17),
                        onSaved: (v) => _itemName = v ?? '',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _paymentMethods.any((m) => m.id == _paymentMethodId)
                                ? _paymentMethodId
                                : null,
                        decoration:
                            const InputDecoration(labelText: '支払方法'),
                        items: _paymentMethods
                            .map((m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text(
                                      '${m.name}${m.isCreditCard ? " (クレジット)" : ""}'),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _paymentMethodId = v ?? ''),
                        validator: (v) =>
                            v == null || v.isEmpty ? '支払方法を選択してください' : null,
                      ),
                    ],

                    if (_type == app.TransactionType.transfer) ...[
                      DropdownButtonFormField<String>(
                        initialValue:
                            _accounts.any((a) => a.id == _fromAccountId)
                                ? _fromAccountId
                                : null,
                        decoration:
                            const InputDecoration(labelText: '振替元資産'),
                        items: _accounts
                            .map((a) => DropdownMenuItem(
                                value: a.id, child: Text(a.name)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _fromAccountId = v ?? ''),
                        validator: (v) =>
                            v == null || v.isEmpty ? '振替元を選択してください' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _accounts.any((a) => a.id == _toAccountId)
                                ? _toAccountId
                                : null,
                        decoration:
                            const InputDecoration(labelText: '振替先資産'),
                        items: _accounts
                            .map((a) => DropdownMenuItem(
                                value: a.id, child: Text(a.name)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _toAccountId = v ?? ''),
                        validator: (v) =>
                            v == null || v.isEmpty ? '振替先を選択してください' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _fee > 0 ? _fee.toString() : '0',
                        decoration: const InputDecoration(
                          labelText: '振込手数料',
                          prefixText: '¥ ',
                        ),
                        style: const TextStyle(fontSize: 17),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _fee = int.tryParse(v ?? '0') ?? 0,
                      ),
                    ],

                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? '更新' : '追加'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
