import 'package:flutter/material.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/transaction_form_screen.dart';
import '../accounts/accounts_screen.dart';
import '../payment_methods/payment_methods_screen.dart';
import '../categories/categories_screen.dart';
import '../settlement/settlement_screen.dart';
import '../help/help_screen.dart';
import 'dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    TransactionsScreen(),
    AccountsScreen(),
    PaymentMethodsScreen(),
    CategoriesScreen(),
    SettlementScreen(),
  ];

  static const _titles = [
    'ダッシュボード',
    '取引一覧',
    '資産管理',
    '支払方法',
    'カテゴリ',
    'クレジット精算',
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final appState = KakeiboApp.of(context);
    final isDark = appState?.themeMode == ThemeMode.dark ||
        (appState?.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          // ダークモード切替
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 22),
            tooltip: isDark ? 'ライトモード' : 'ダークモード',
            onPressed: () => appState?.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 26,
            tooltip: '取引を追加',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TransactionFormScreen()),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            padding: const EdgeInsets.all(12),
            onSelected: (value) async {
              if (value == 'help') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              } else if (value == 'logout') {
                await AuthService().signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'help',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 20),
                    SizedBox(width: 12),
                    Text('使い方', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('ログアウト', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              minWidth: 80,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('ホーム'),
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('取引'),
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance),
                  label: Text('資産'),
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.payment_outlined),
                  selectedIcon: Icon(Icons.payment),
                  label: Text('支払'),
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: Text('カテゴリ'),
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.credit_score_outlined),
                  selectedIcon: Icon(Icons.credit_score),
                  label: Text('精算'),
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
              ],
            ),
          if (isWide)
            const VerticalDivider(width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'ホーム',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: '取引',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance),
                  label: '資産',
                ),
                NavigationDestination(
                  icon: Icon(Icons.payment_outlined),
                  selectedIcon: Icon(Icons.payment),
                  label: '支払',
                ),
                NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: 'カテゴリ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.credit_score_outlined),
                  selectedIcon: Icon(Icons.credit_score),
                  label: '精算',
                ),
              ],
            ),
    );
  }
}
