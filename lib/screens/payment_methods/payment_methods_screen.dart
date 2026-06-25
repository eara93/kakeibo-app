import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/payment_method.dart';
import '../../models/account.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _service = FirestoreService();
  final _nameController = TextEditingController();
  PaymentMethodType _type = PaymentMethodType.cash;
  String _linkedAccountId = '';
  int _closingDay = 31;
  int _paymentDay = 25;
  int _paymentMonthOffset = 1;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addPaymentMethod() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _linkedAccountId.isEmpty) return;

    await _service.addPaymentMethod(PaymentMethod(
      id: '',
      name: name,
      type: _type,
      linkedAccountId: _linkedAccountId,
      creditSettings: _type == PaymentMethodType.creditCard
          ? CreditSettings(
              closingDay: _closingDay,
              paymentDay: _paymentDay,
              paymentMonthOffset: _paymentMonthOffset,
            )
          : null,
    ));

    _nameController.clear();
    setState(() {
      _type = PaymentMethodType.cash;
      _linkedAccountId = '';
    });
  }

  Future<void> _deletePaymentMethod(PaymentMethod method) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${method.name}」を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deletePaymentMethod(method.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${method.name}」を削除しました')),
        );
      }
    }
  }

  Future<void> _editPaymentMethod(
      PaymentMethod method, List<Account> accounts) async {
    final nameCtrl = TextEditingController(text: method.name);
    var editType = method.type;
    var editLinkedAccountId = method.linkedAccountId;
    var editClosingDay = method.creditSettings?.closingDay ?? 31;
    var editPaymentDay = method.creditSettings?.paymentDay ?? 25;
    var editMonthOffset = method.creditSettings?.paymentMonthOffset ?? 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('支払方法を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '名称'),
                  style: const TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethodType>(
                  initialValue: editType,
                  decoration: const InputDecoration(labelText: '種類'),
                  items: [
                    DropdownMenuItem(
                        value: PaymentMethodType.cash,
                        child: Text('現金・即時')),
                    DropdownMenuItem(
                        value: PaymentMethodType.creditCard,
                        child: Text('クレジットカード')),
                    DropdownMenuItem(
                        value: PaymentMethodType.balancePayment,
                        child: Text('残高払い')),
                    DropdownMenuItem(
                        value: PaymentMethodType.other,
                        child: Text('その他')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => editType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      accounts.any((a) => a.id == editLinkedAccountId)
                          ? editLinkedAccountId
                          : null,
                  decoration: const InputDecoration(labelText: '紐付け資産'),
                  items: accounts
                      .map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => editLinkedAccountId = v ?? ''),
                ),
                if (editType == PaymentMethodType.creditCard) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: editClosingDay.toString(),
                          decoration:
                              const InputDecoration(labelText: '締め日'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              editClosingDay = int.tryParse(v) ?? 31,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: editPaymentDay.toString(),
                          decoration:
                              const InputDecoration(labelText: '引落日'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              editPaymentDay = int.tryParse(v) ?? 25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: editMonthOffset,
                    decoration:
                        const InputDecoration(labelText: '引落月'),
                    items: [
                      DropdownMenuItem(value: 1, child: Text('翌月')),
                      DropdownMenuItem(value: 2, child: Text('翌々月')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => editMonthOffset = v ?? 1),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存')),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await _service.updatePaymentMethod(PaymentMethod(
        id: method.id,
        name: nameCtrl.text.trim(),
        type: editType,
        linkedAccountId: editLinkedAccountId,
        creditSettings: editType == PaymentMethodType.creditCard
            ? CreditSettings(
                closingDay: editClosingDay,
                paymentDay: editPaymentDay,
                paymentMonthOffset: editMonthOffset,
              )
            : null,
        sortOrder: method.sortOrder,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支払方法を更新しました')),
        );
      }
    }
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentMethod>>(
      stream: _service.watchPaymentMethods(),
      builder: (context, pmSnap) {
        return StreamBuilder<List<Account>>(
          stream: _service.watchAccounts(),
          builder: (context, accSnap) {
            if (!pmSnap.hasData || !accSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final methods = pmSnap.data!;
            final accounts = accSnap.data!;
            final accMap = {for (final a in accounts) a.id: a.name};

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAddForm(accounts),
                      const SizedBox(height: 8),
                      if (methods.isNotEmpty)
                        Card(
                          child: Column(
                            children: [
                              for (int i = 0; i < methods.length; i++) ...[
                                _buildMethodRow(methods[i], accMap, accounts),
                                if (i < methods.length - 1) const Divider(),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddForm(List<Account> accounts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('支払方法を追加',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93))),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称'),
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethodType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '種類'),
              items: [
                DropdownMenuItem(
                    value: PaymentMethodType.cash,
                    child: Text('現金・即時')),
                DropdownMenuItem(
                    value: PaymentMethodType.creditCard,
                    child: Text('クレジットカード')),
                DropdownMenuItem(
                    value: PaymentMethodType.balancePayment,
                    child: Text('残高払い')),
                DropdownMenuItem(
                    value: PaymentMethodType.other,
                    child: Text('その他')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: accounts.any((a) => a.id == _linkedAccountId)
                  ? _linkedAccountId
                  : null,
              decoration: const InputDecoration(labelText: '紐付け資産'),
              items: accounts
                  .map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.name)))
                  .toList(),
              onChanged: (v) => setState(() => _linkedAccountId = v ?? ''),
            ),
            if (_type == PaymentMethodType.creditCard) ...[
              const SizedBox(height: 16),
              const Text('クレジット設定',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _closingDay.toString(),
                      decoration: const InputDecoration(labelText: '締め日'),
                      style: const TextStyle(fontSize: 17),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _closingDay = int.tryParse(v) ?? 31,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _paymentDay.toString(),
                      decoration: const InputDecoration(labelText: '引落日'),
                      style: const TextStyle(fontSize: 17),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _paymentDay = int.tryParse(v) ?? 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _paymentMonthOffset,
                      decoration: const InputDecoration(labelText: '引落月'),
                      items: [
                        DropdownMenuItem(value: 1, child: Text('翌月')),
                        DropdownMenuItem(value: 2, child: Text('翌々月')),
                      ],
                      onChanged: (v) =>
                          setState(() => _paymentMonthOffset = v ?? 1),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _addPaymentMethod,
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodRow(
      PaymentMethod method, Map<String, String> accMap, List<Account> accounts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.name,
                    style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 4),
                Text(
                  '${method.typeLabel}  •  ${accMap[method.linkedAccountId] ?? "未設定"}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF8E8E93)),
                ),
                if (method.creditSettings != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '締め${method.creditSettings!.closingDay}日 / '
                      '引落${method.creditSettings!.paymentDay}日 / '
                      '${method.creditSettings!.paymentMonthOffset == 1 ? "翌月" : "翌々月"}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: Color(0xFF8E8E93)),
              onPressed: () => _editPaymentMethod(method, accounts),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Color(0xFFC7C7CC)),
              onPressed: () => _deletePaymentMethod(method),
            ),
          ),
        ],
      ),
    );
  }
}
