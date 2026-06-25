import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction.dart' as app;
import '../../models/payment_method.dart';
import '../../models/account.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final _service = FirestoreService();
  final _fmt = NumberFormat('#,###', 'ja_JP');

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

            final paymentMethods = pmSnap.data!;
            final accounts = accSnap.data!;
            final creditCards =
                paymentMethods.where((pm) => pm.isCreditCard).toList();

            if (creditCards.isEmpty) {
              return Center(
                child: Text('クレジットカードが登録されていません',
                    style: TextStyle(fontSize: 15, color: Colors.grey[500])),
              );
            }

            return StreamBuilder<List<app.Transaction>>(
              stream: _service.watchUnsettledTransactions(),
              builder: (context, txSnap) {
                if (!txSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final unsettled = txSnap.data!;
                final accMap = {for (final a in accounts) a.id: a};

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: creditCards.map((card) {
                          final cardTxs = unsettled
                              .where((tx) =>
                                  tx.paymentMethodId == card.id)
                              .toList();
                          return _buildCardSection(
                              card, cardTxs, accMap[card.linkedAccountId]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCardSection(
    PaymentMethod card,
    List<app.Transaction> transactions,
    Account? account,
  ) {
    final totalUnsettled =
        transactions.fold<int>(0, (sum, tx) => sum + tx.amount);

    final monthGroups = <String, List<app.Transaction>>{};
    for (final tx in transactions) {
      final key = DateFormat('yyyy/MM').format(tx.date);
      monthGroups.putIfAbsent(key, () => []).add(tx);
    }
    final sortedMonths = monthGroups.keys.toList()..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カード情報ヘッダー
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card,
                      color: Color(0xFFFF9500), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (card.creditSettings != null)
                        Text(
                          '締め${card.creditSettings!.closingDay}日 / 引落${card.creditSettings!.paymentDay}日',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF8E8E93)),
                        ),
                      if (account != null)
                        Text(
                          '${account.name}  ¥${_fmt.format(account.balance)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF8E8E93)),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('未精算',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF8E8E93))),
                    const SizedBox(height: 2),
                    Text(
                      '¥${_fmt.format(totalUnsettled)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF9500),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (transactions.isEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('未精算の取引はありません',
                    style: TextStyle(
                        fontSize: 15, color: Color(0xFF8E8E93))),
              ),
            ],

            // 月別グループ
            ...sortedMonths.map((month) {
              final monthTxs = monthGroups[month]!;
              final monthTotal =
                  monthTxs.fold<int>(0, (sum, tx) => sum + tx.amount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(month,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Text('¥${_fmt.format(monthTotal)}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 36,
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                minimumSize: const Size(44, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () =>
                                  _settleMonth(monthTxs, card),
                              child: const Text('精算',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...monthTxs.map((tx) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                DateFormat('MM/dd').format(tx.date),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8E8E93)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                [tx.category, tx.itemName]
                                    .where((s) => s.isNotEmpty)
                                    .join('  '),
                                style: const TextStyle(fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '¥${_fmt.format(tx.amount)}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      )),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _settleMonth(
      List<app.Transaction> transactions, PaymentMethod card) async {
    final total =
        transactions.fold<int>(0, (sum, tx) => sum + tx.amount);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('精算確認'),
        content: Text(
          '${transactions.length}件の取引\n合計 ¥${_fmt.format(total)}\n\n精算して引落先の資産を更新しますか？',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('精算する')),
        ],
      ),
    );

    if (confirm == true) {
      await _service.settleTransactions(
          transactions, card.linkedAccountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${transactions.length}件を精算しました（¥${_fmt.format(total)}）'),
          ),
        );
      }
    }
  }
}
