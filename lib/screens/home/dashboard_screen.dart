import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firestore_service.dart';
import '../../models/account.dart';
import '../../models/transaction.dart' as app;
import '../../models/payment_method.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = FirestoreService();
  final _fmt = NumberFormat('#,###', 'ja_JP');
  List<String> _sectionOrder = [];
  String? _chartMonth;

  @override
  void initState() {
    super.initState();
    _loadDashboardOrder();
  }

  Future<void> _loadDashboardOrder() async {
    final order = await _service.getDashboardOrder();
    if (mounted) setState(() => _sectionOrder = order);
  }

  Future<void> _saveDashboardOrder() async {
    await _service.saveDashboardOrder(_sectionOrder);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: _service.watchAccounts(),
      builder: (context, accountsSnap) {
        return StreamBuilder<List<app.Transaction>>(
          stream: _service.watchTransactions(),
          builder: (context, txSnap) {
            return StreamBuilder<List<PaymentMethod>>(
              stream: _service.watchPaymentMethods(),
              builder: (context, pmSnap) {
                if (!accountsSnap.hasData ||
                    !txSnap.hasData ||
                    !pmSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildDashboard(
                  context,
                  accountsSnap.data!,
                  txSnap.data!,
                  pmSnap.data!,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<Account> accounts,
    List<app.Transaction> transactions,
    List<PaymentMethod> paymentMethods,
  ) {
    final totalAssets = accounts.fold<int>(0, (sum, a) => sum + a.balance);
    final unsettled = transactions
        .where((t) => t.isProvisional && !t.settled)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final projected = totalAssets - unsettled;

    if (_sectionOrder.isEmpty) {
      _sectionOrder = FirestoreService.defaultDashboardOrder.toList();
    }

    final sections = <String, Widget>{
      'assets': _buildAssetsCard(totalAssets, unsettled, projected),
      'account_balances': _buildAccountBalances(accounts),
      'monthly_summary': _buildMonthlySummary(transactions),
      'yearly_summary': _buildYearlySummary(transactions),
      'expense_chart': _buildExpenseChart(transactions),
      'recent_transactions':
          _buildRecentTransactions(transactions, paymentMethods),
    };

    final sectionTitles = {
      'assets': '資産概要',
      'account_balances': '口座残高',
      'monthly_summary': '月別サマリー',
      'yearly_summary': '年別サマリー',
      'expense_chart': '支出内訳',
      'recent_transactions': '最近の取引',
    };

    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _sectionOrder.removeAt(oldIndex);
          _sectionOrder.insert(newIndex, item);
        });
        _saveDashboardOrder();
      },
      children: [
        for (final key in _sectionOrder)
          if (sections.containsKey(key))
            _DashboardSection(
              key: ValueKey(key),
              title: sectionTitles[key] ?? key,
              child: sections[key]!,
            ),
      ],
    );
  }

  Widget _buildAssetsCard(int total, int unsettled, int projected) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Expanded(child: _assetItem('総資産', total, const Color(0xFF007AFF))),
            Container(width: 0.5, height: 40, color: const Color(0xFFD1D1D6)),
            Expanded(
                child: _assetItem('未精算', unsettled, const Color(0xFFFF9500))),
            Container(width: 0.5, height: 40, color: const Color(0xFFD1D1D6)),
            Expanded(
              child: _assetItem(
                '実質資産',
                projected,
                projected >= 0
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetItem(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF8E8E93), height: 1.4)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '¥${_fmt.format(amount)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountBalances(List<Account> accounts) {
    if (accounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('口座が登録されていません',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            for (int i = 0; i < accounts.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(accounts[i].name,
                        style: const TextStyle(fontSize: 15)),
                    Text(
                      '¥${_fmt.format(accounts[i].balance)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: accounts[i].balance >= 0
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < accounts.length - 1)
                const Divider(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary(List<app.Transaction> transactions) {
    final now = DateTime.now();
    final months = <String, Map<String, int>>{};

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy/MM').format(d);
      months[key] = {'income': 0, 'expense': 0};
    }

    for (final tx in transactions) {
      if (tx.type == app.TransactionType.transfer) continue;
      final key = DateFormat('yyyy/MM').format(tx.date);
      if (!months.containsKey(key)) continue;
      if (tx.type == app.TransactionType.income) {
        months[key]!['income'] = months[key]!['income']! + tx.amount;
      } else {
        months[key]!['expense'] = months[key]!['expense']! + tx.amount;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 44,
            headingTextStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
            columns: const [
              DataColumn(label: Text('月')),
              DataColumn(label: Text('収入'), numeric: true),
              DataColumn(label: Text('支出'), numeric: true),
              DataColumn(label: Text('収支'), numeric: true),
            ],
            rows: months.entries.map((e) {
              final income = e.value['income']!;
              final expense = e.value['expense']!;
              final net = income - expense;
              return DataRow(cells: [
                DataCell(Text(e.key, style: const TextStyle(fontSize: 14))),
                DataCell(Text('¥${_fmt.format(income)}',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF34C759)))),
                DataCell(Text('¥${_fmt.format(expense)}',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFFFF3B30)))),
                DataCell(Text(
                  '¥${_fmt.format(net)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: net >= 0
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildYearlySummary(List<app.Transaction> transactions) {
    final years = <String, Map<String, int>>{};
    for (final tx in transactions) {
      if (tx.type == app.TransactionType.transfer) continue;
      final key = tx.date.year.toString();
      years.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (tx.type == app.TransactionType.income) {
        years[key]!['income'] = years[key]!['income']! + tx.amount;
      } else {
        years[key]!['expense'] = years[key]!['expense']! + tx.amount;
      }
    }
    final sortedKeys = years.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedKeys.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('データがありません',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 44,
            headingTextStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
            columns: const [
              DataColumn(label: Text('年')),
              DataColumn(label: Text('収入'), numeric: true),
              DataColumn(label: Text('支出'), numeric: true),
              DataColumn(label: Text('収支'), numeric: true),
            ],
            rows: sortedKeys.map((key) {
              final income = years[key]!['income']!;
              final expense = years[key]!['expense']!;
              final net = income - expense;
              return DataRow(cells: [
                DataCell(
                    Text('$key年', style: const TextStyle(fontSize: 14))),
                DataCell(Text('¥${_fmt.format(income)}',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF34C759)))),
                DataCell(Text('¥${_fmt.format(expense)}',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFFFF3B30)))),
                DataCell(Text(
                  '¥${_fmt.format(net)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: net >= 0
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseChart(List<app.Transaction> transactions) {
    final now = DateTime.now();
    final availableMonths = <String>{};
    for (final tx in transactions) {
      if (tx.type == app.TransactionType.expense) {
        availableMonths.add(DateFormat('yyyy/MM').format(tx.date));
      }
    }
    final sortedMonths = availableMonths.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedMonths.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('支出データがありません',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ),
      );
    }

    _chartMonth ??= DateFormat('yyyy/MM').format(now);
    if (!sortedMonths.contains(_chartMonth)) {
      _chartMonth = sortedMonths.first;
    }

    final expenses = transactions.where((tx) {
      if (tx.type != app.TransactionType.expense) return false;
      return DateFormat('yyyy/MM').format(tx.date) == _chartMonth;
    }).toList();

    final categoryTotals = <String, int>{};
    for (final tx in expenses) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final total = categoryTotals.values.fold<int>(0, (s, v) => s + v);
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFFFF3B30),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFAF52DE),
      const Color(0xFF5AC8FA),
      const Color(0xFFFF2D55),
      const Color(0xFFFFCC00),
      const Color(0xFF5856D6),
      const Color(0xFF00C7BE),
    ];

    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _chartMonth,
                underline: const SizedBox(),
                items: sortedMonths
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _chartMonth = v),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: entries.asMap().entries.map((e) {
                    final idx = e.key;
                    final entry = e.value;
                    final pct =
                        total > 0 ? (entry.value / total * 100) : 0.0;
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: pct >= 5
                          ? '¥${_fmt.format(entry.value)}'
                          : '',
                      color: colors[idx % colors.length],
                      radius: 70,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                final pct = total > 0
                    ? (entry.value / total * 100).toStringAsFixed(1)
                    : '0.0';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[idx % colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${entry.key} ($pct%)',
                        style: const TextStyle(fontSize: 13)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
    List<app.Transaction> transactions,
    List<PaymentMethod> paymentMethods,
  ) {
    final recent = transactions.take(10).toList();
    if (recent.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('取引がありません',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < recent.length; i++) ...[
            _buildRecentItem(recent[i]),
            if (i < recent.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 60),
                child: Divider(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentItem(app.Transaction tx) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.itemName.isNotEmpty ? tx.itemName : tx.category,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MM/dd').format(tx.date)}  ${tx.category}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          Text(
            '${tx.type == app.TransactionType.income ? '+' : '-'}¥${_fmt.format(tx.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tx.type == app.TransactionType.income
                  ? const Color(0xFF34C759)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DashboardSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6, top: 12),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator,
                    size: 18, color: Color(0xFFC7C7CC)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
