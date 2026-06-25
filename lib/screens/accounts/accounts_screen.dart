import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/account.dart';
import '../../models/payment_method.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _service = FirestoreService();
  final _fmt = NumberFormat('#,###', 'ja_JP');
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AssetType _assetType = AssetType.bankAccount;
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _adding) return;
    final balanceText = _balanceController.text.trim();
    if (balanceText.isNotEmpty && int.tryParse(balanceText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('残高は数値で入力してください')),
      );
      return;
    }
    final balance = int.tryParse(balanceText) ?? 0;

    setState(() => _adding = true);
    try {
      await _service.addAccount(Account(
        id: '',
        name: name,
        balance: balance,
        assetType: _assetType,
      ));

      // 残高タイプの場合、支払方法を自動追加
      if (_assetType == AssetType.balance) {
        final accounts = await _service.getAccounts();
        final newAccount = accounts.where((a) => a.name == name).firstOrNull;
        if (newAccount != null) {
          await _service.addPaymentMethod(PaymentMethod(
            id: '',
            name: name,
            type: PaymentMethodType.balancePayment,
            linkedAccountId: newAccount.id,
          ));
        }
      }

      _nameController.clear();
      _balanceController.clear();
      setState(() => _assetType = AssetType.bankAccount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$name」を追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _editAccount(Account account) async {
    final nameCtrl = TextEditingController(text: account.name);
    final balanceCtrl =
        TextEditingController(text: account.balance.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('資産を編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '資産名'),
              style: const TextStyle(fontSize: 17),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceCtrl,
              decoration: const InputDecoration(
                labelText: '残高', prefixText: '¥ ',
              ),
              style: const TextStyle(fontSize: 17),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
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
    );

    if (result == true) {
      await _service.updateAccount(account.copyWith(
        name: nameCtrl.text.trim(),
        balance: int.tryParse(balanceCtrl.text) ?? account.balance,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('資産を更新しました')),
        );
      }
    }
    nameCtrl.dispose();
    balanceCtrl.dispose();
  }

  Future<void> _deleteAccount(Account account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${account.name}」を削除しますか？'),
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
      await _service.deleteAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${account.name}」を削除しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: _service.watchAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snapshot.data!;
        final total = accounts.fold<int>(0, (s, a) => s + a.balance);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (accounts.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text('総資産',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              '¥${_fmt.format(total)}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: total >= 0
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFFF3B30),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 追加フォーム
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '資産名',
                              hintText: '例: 銀行口座、PayPay',
                            ),
                            style: const TextStyle(fontSize: 17),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<AssetType>(
                            initialValue: _assetType,
                            decoration:
                                const InputDecoration(labelText: '資産種類'),
                            items: [
                              DropdownMenuItem(
                                  value: AssetType.bankAccount,
                                  child: Text('口座')),
                              DropdownMenuItem(
                                  value: AssetType.balance,
                                  child: Text('残高')),
                              DropdownMenuItem(
                                  value: AssetType.cash,
                                  child: Text('現金')),
                            ],
                            onChanged: (v) =>
                                setState(() => _assetType = v!),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _balanceController,
                            decoration: const InputDecoration(
                              labelText: '初期残高', prefixText: '¥ ',
                              hintText: '0',
                            ),
                            style: const TextStyle(fontSize: 17),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _addAccount(),
                          ),
                          if (_assetType == AssetType.balance)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '※ 支払方法「残高払い」が自動で追加されます',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _adding ? null : _addAccount,
                            child: _adding
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('追加'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (accounts.isNotEmpty)
                    Card(
                      child: Column(
                        children: [
                          for (int i = 0; i < accounts.length; i++) ...[
                            _buildAccountRow(accounts[i]),
                            if (i < accounts.length - 1) const Divider(),
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
  }

  Widget _buildAccountRow(Account account) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(account.name, style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        account.assetTypeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${_fmt.format(account.balance)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: account.balance >= 0
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44, height: 44,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: Color(0xFF8E8E93)),
              onPressed: () => _editAccount(account),
            ),
          ),
          SizedBox(
            width: 44, height: 44,
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Color(0xFFC7C7CC)),
              onPressed: () => _deleteAccount(account),
            ),
          ),
        ],
      ),
    );
  }
}
