import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction.dart' as app;
import '../../models/account.dart';
import '../../models/category.dart' show Category, CategoryType;
import '../../models/payment_method.dart';
import '../../models/favorite.dart';

class TransactionFormScreen extends StatefulWidget {
  final app.Transaction? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _service = FirestoreService();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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

  // 取引種別に合わせてカテゴリをフィルタ
  List<Category> get _filteredCategories {
    if (_type == app.TransactionType.income) {
      return _categories.where((c) => c.type == CategoryType.income).toList();
    }
    return _categories.where((c) => c.type == CategoryType.expense).toList();
  }

  // フォーム再構築用キー
  Key _formRebuildKey = UniqueKey();

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
        if (_isEditing) {
          Navigator.pop(context);
        } else {
          setState(() {
            _category = '';
            _itemName = '';
            _amount = 0;
            _paymentMethodId = '';
            _fromAccountId = '';
            _toAccountId = '';
            _fee = 0;
            _formRebuildKey = UniqueKey();
            _formKey = GlobalKey<FormState>();
          });
        }
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

  Future<void> _saveAsFavorite() async {
    _formKey.currentState?.save();
    final nameCtrl = TextEditingController(text: _itemName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('お気に入りに追加'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'お気に入り名'),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text),
              child: const Text('保存')),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _service.addFavorite(Favorite(
        id: '',
        name: result.trim(),
        type: _type,
        category: _category,
        itemName: _itemName,
        amount: _amount,
        paymentMethodId: _paymentMethodId,
        toAccountId: _toAccountId,
        fromAccountId: _fromAccountId,
        fee: _fee,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${result.trim()}」をお気に入りに追加しました')),
        );
      }
    }
    nameCtrl.dispose();
  }

  void _loadFavorite(Favorite fav) {
    setState(() {
      _type = fav.type;
      _category = fav.category;
      _itemName = fav.itemName;
      _amount = fav.amount;
      _paymentMethodId = fav.paymentMethodId;
      _toAccountId = fav.toAccountId;
      _fromAccountId = fav.fromAccountId;
      _fee = fav.fee;
      _formRebuildKey = UniqueKey();
      _formKey = GlobalKey<FormState>();
    });
  }

  Future<void> _showFavorites() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StreamBuilder<List<Favorite>>(
          stream: _service.watchFavorites(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final favorites = snapshot.data!;
            if (favorites.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text('お気に入りがありません',
                      style: TextStyle(fontSize: 15)),
                ),
              );
            }
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('お気に入りから入力',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: favorites.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final fav = favorites[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          title: Text(fav.name,
                              style: const TextStyle(fontSize: 16)),
                          subtitle: Text(
                            '${fav.type == app.TransactionType.income ? "収入" : fav.type == app.TransactionType.expense ? "支出" : "振替"}'
                            '${fav.category.isNotEmpty ? "  ${fav.category}" : ""}'
                            '${fav.amount > 0 ? "  ¥${NumberFormat("#,###", "ja_JP").format(fav.amount)}" : ""}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await _service.deleteFavorite(fav.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('「${fav.name}」を削除しました')),
                                );
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _loadFavorite(fav);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '取引を編集' : '取引を追加'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'お気に入りから入力',
            onPressed: _showFavorites,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: KeyedSubtree(
                key: _formRebuildKey,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        onSelectionChanged: (s) => setState(() {
                          _type = s.first;
                          _category = ''; // 種別変更時にカテゴリをリセット
                        }),
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
                            suffixIcon:
                                const Icon(Icons.calendar_today, size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          child: Text(
                            DateFormat('yyyy年M月d日').format(_date),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // カテゴリ（振替以外）
                      if (_type != app.TransactionType.transfer)
                        DropdownButtonFormField<String>(
                          initialValue:
                              _filteredCategories.any((c) => c.name == _category)
                                  ? _category
                                  : null,
                          decoration:
                              const InputDecoration(labelText: 'カテゴリ'),
                          items: _filteredCategories
                              .map((c) => DropdownMenuItem(
                                  value: c.name, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _category = v ?? ''),
                          validator: (v) => v == null || v.isEmpty
                              ? 'カテゴリを選択してください'
                              : null,
                        ),
                      const SizedBox(height: 16),

                      // 金額
                      TextFormField(
                        initialValue:
                            _amount > 0 ? _amount.toString() : '',
                        decoration: const InputDecoration(
                          labelText: '金額',
                          prefixText: '¥ ',
                          hintText: '0',
                        ),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return '金額を入力してください';
                          }
                          if (int.tryParse(v) == null ||
                              int.parse(v) <= 0) {
                            return '有効な金額を入力してください';
                          }
                          return null;
                        },
                        onSaved: (v) => _amount = int.tryParse(v ?? '') ?? _amount,
                      ),
                      const SizedBox(height: 16),

                      // 収入
                      if (_type == app.TransactionType.income) ...[
                        TextFormField(
                          initialValue: _itemName,
                          decoration: const InputDecoration(
                              labelText: '品名・メモ'),
                          style: const TextStyle(fontSize: 17),
                          onSaved: (v) => _itemName = v ?? '',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                              _accounts.any((a) => a.id == _toAccountId)
                                  ? _toAccountId
                                  : null,
                          decoration: const InputDecoration(
                              labelText: '受取先'),
                          items: _accounts
                              .map((a) => DropdownMenuItem(
                                  value: a.id, child: Text(a.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _toAccountId = v ?? ''),
                          validator: (v) => v == null || v.isEmpty
                              ? '受取先を選択してください'
                              : null,
                        ),
                      ],

                      // 支出
                      if (_type == app.TransactionType.expense) ...[
                        TextFormField(
                          initialValue: _itemName,
                          decoration: const InputDecoration(
                              labelText: '品名・メモ'),
                          style: const TextStyle(fontSize: 17),
                          onSaved: (v) => _itemName = v ?? '',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _paymentMethods
                                  .any((m) => m.id == _paymentMethodId)
                              ? _paymentMethodId
                              : null,
                          decoration: const InputDecoration(
                              labelText: '支払方法'),
                          items: _paymentMethods
                              .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(
                                        '${m.name}${m.isCreditCard ? " (クレジット)" : ""}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _paymentMethodId = v ?? ''),
                          validator: (v) => v == null || v.isEmpty
                              ? '支払方法を選択してください'
                              : null,
                        ),
                      ],

                      // 振替
                      if (_type == app.TransactionType.transfer) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _accounts
                                  .any((a) => a.id == _fromAccountId)
                              ? _fromAccountId
                              : null,
                          decoration: const InputDecoration(
                              labelText: '振替元資産'),
                          items: _accounts
                              .map((a) => DropdownMenuItem(
                                  value: a.id, child: Text(a.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _fromAccountId = v ?? ''),
                          validator: (v) => v == null || v.isEmpty
                              ? '振替元を選択してください'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                              _accounts.any((a) => a.id == _toAccountId)
                                  ? _toAccountId
                                  : null,
                          decoration: const InputDecoration(
                              labelText: '振替先資産'),
                          items: _accounts
                              .map((a) => DropdownMenuItem(
                                  value: a.id, child: Text(a.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _toAccountId = v ?? ''),
                          validator: (v) => v == null || v.isEmpty
                              ? '振替先を選択してください'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue:
                              _fee > 0 ? _fee.toString() : '',
                          decoration: const InputDecoration(
                            labelText: '振込手数料',
                            prefixText: '¥ ',
                            hintText: '0',
                          ),
                          style: const TextStyle(fontSize: 17),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (v) =>
                              _fee = int.tryParse(v ?? '0') ?? 0,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // お気に入り保存ボタン
                      OutlinedButton.icon(
                        onPressed: _saveAsFavorite,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('お気に入りに追加'),
                      ),

                      const SizedBox(height: 12),

                      FilledButton(
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
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
      ),
    );
  }
}
