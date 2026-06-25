import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction.dart' as app;
import '../../models/payment_method.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _service = FirestoreService();
  final _fmt = NumberFormat('#,###', 'ja_JP');
  app.TransactionType? _filterType;
  String? _filterMonth;
  String? _filterPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<app.Transaction>>(
      stream: _service.watchTransactions(),
      builder: (context, txSnap) {
        return StreamBuilder<List<PaymentMethod>>(
          stream: _service.watchPaymentMethods(),
          builder: (context, pmSnap) {
            if (!txSnap.hasData || !pmSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final transactions = txSnap.data!;
            final paymentMethods = pmSnap.data!;
            final pmMap = {for (final pm in paymentMethods) pm.id: pm};

            final months = <String>{};
            for (final tx in transactions) {
              months.add(DateFormat('yyyy/MM').format(tx.date));
            }
            final sortedMonths = months.toList()
              ..sort((a, b) => b.compareTo(a));

            var filtered = transactions.where((tx) {
              if (_filterType != null && tx.type != _filterType) return false;
              if (_filterMonth != null &&
                  DateFormat('yyyy/MM').format(tx.date) != _filterMonth) {
                return false;
              }
              if (_filterPaymentMethod != null &&
                  tx.paymentMethodId != _filterPaymentMethod) {
                return false;
              }
              return true;
            }).toList();

            return Column(
              children: [
                _buildFilters(sortedMonths, paymentMethods),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('取引がありません',
                              style: TextStyle(
                                  fontSize: 15, color: Colors.grey[500])),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              _buildTransactionTile(
                                  filtered[i], pmMap, paymentMethods),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilters(
      List<String> months, List<PaymentMethod> paymentMethods) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              label: _filterType != null
                  ? {
                      app.TransactionType.income: '収入',
                      app.TransactionType.expense: '支出',
                      app.TransactionType.transfer: '振替',
                    }[_filterType]!
                  : '種類',
              isSelected: _filterType != null,
              onTap: () => _showFilterMenu<app.TransactionType?>(
                items: [
                  _filterMenuItem(null, 'すべて'),
                  _filterMenuItem(app.TransactionType.income, '収入'),
                  _filterMenuItem(app.TransactionType.expense, '支出'),
                  _filterMenuItem(app.TransactionType.transfer, '振替'),
                ],
                onSelected: (v) => setState(() => _filterType = v),
              ),
            ),
            const SizedBox(width: 8),
            _filterChip(
              label: _filterMonth ?? '月',
              isSelected: _filterMonth != null,
              onTap: () => _showFilterMenu<String?>(
                items: [
                  _filterMenuItem(null, 'すべて'),
                  ...months.map((m) => _filterMenuItem(m, m)),
                ],
                onSelected: (v) => setState(() => _filterMonth = v),
              ),
            ),
            const SizedBox(width: 8),
            _filterChip(
              label: _filterPaymentMethod != null
                  ? paymentMethods
                          .where((pm) => pm.id == _filterPaymentMethod)
                          .firstOrNull
                          ?.name ??
                      '支払方法'
                  : '支払方法',
              isSelected: _filterPaymentMethod != null,
              onTap: () => _showFilterMenu<String?>(
                items: [
                  _filterMenuItem(null, 'すべて'),
                  ...paymentMethods
                      .map((pm) => _filterMenuItem(pm.id, pm.name)),
                ],
                onSelected: (v) =>
                    setState(() => _filterPaymentMethod = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF).withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF)
                : const Color(0xFFD1D1D6),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isSelected
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF8E8E93),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<T> _filterMenuItem<T>(T value, String label) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Text(label, style: const TextStyle(fontSize: 15)),
    );
  }

  void _showFilterMenu<T>({
    required List<PopupMenuItem<T>> items,
    required ValueChanged<T> onSelected,
  }) async {
    final renderBox = context.findRenderObject() as RenderBox;
    final result = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(0, 100, renderBox.size.width, 0),
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    if (result is T) {
      onSelected(result);
    }
  }

  Widget _buildTransactionTile(
    app.Transaction tx,
    Map<String, PaymentMethod> pmMap,
    List<PaymentMethod> paymentMethods,
  ) {
    Color typeColor;
    IconData typeIcon;
    switch (tx.type) {
      case app.TransactionType.income:
        typeColor = const Color(0xFF34C759);
        typeIcon = Icons.arrow_downward_rounded;
        break;
      case app.TransactionType.expense:
        typeColor = const Color(0xFFFF3B30);
        typeIcon = Icons.arrow_upward_rounded;
        break;
      case app.TransactionType.transfer:
        typeColor = const Color(0xFF007AFF);
        typeIcon = Icons.swap_horiz_rounded;
        break;
    }

    final pmName = pmMap[tx.paymentMethodId]?.name ?? '';

    final isSettled = tx.isProvisional && tx.settled;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSettled
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('精算済みの取引は編集できません')),
                )
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionFormScreen(transaction: tx),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.itemName.isNotEmpty ? tx.itemName : tx.category,
                      style: const TextStyle(fontSize: 15, height: 1.3),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        DateFormat('yyyy/MM/dd').format(tx.date),
                        if (tx.category.isNotEmpty) tx.category,
                        if (pmName.isNotEmpty) pmName,
                      ].join('  '),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF8E8E93)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${_fmt.format(tx.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tx.type == app.TransactionType.income
                          ? const Color(0xFF34C759)
                          : null,
                    ),
                  ),
                  if (tx.isProvisional)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tx.settled
                            ? const Color(0xFF5AC8FA).withValues(alpha: 0.15)
                            : const Color(0xFFFF9500).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tx.settled ? '精算済' : '未精算',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: tx.settled
                              ? const Color(0xFF32ADE6)
                              : const Color(0xFFFF9500),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              if (!isSettled)
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('削除確認'),
                        content: const Text('この取引を削除しますか？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('キャンセル')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF3B30)),
                              child: const Text('削除')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.deleteTransaction(tx, paymentMethods);
                    }
                  },
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.delete_outline,
                        size: 20, color: Color(0xFFC7C7CC)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
