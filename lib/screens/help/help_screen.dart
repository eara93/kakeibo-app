import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('使い方')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _HelpSection(
              icon: Icons.dashboard,
              color: const Color(0xFF007AFF),
              title: 'ダッシュボード',
              items: const [
                '総資産・未精算額・実質資産を一目で確認できます',
                '月別・年別の収支サマリーを表示します',
                '支出内訳を円グラフで確認できます',
                '各セクションはドラッグで並び替え可能です',
              ],
            ),
            _HelpSection(
              icon: Icons.receipt_long,
              color: const Color(0xFF34C759),
              title: '取引',
              items: const [
                '右上の＋アイコンからどの画面でも取引を追加できます',
                '支出・収入・振替の3種類を登録できます',
                '支出は支払方法、収入は受取先の資産を選択します',
                'フィルターで種類・月・支払方法で絞り込めます',
                '追加後はフォームがリセットされ続けて入力できます',
                '精算済みの取引は編集・削除できません',
              ],
            ),
            _HelpSection(
              icon: Icons.bookmark,
              color: const Color(0xFFFF9500),
              title: 'お気に入り',
              items: const [
                '取引入力画面の「お気に入りに追加」で保存できます',
                '右上のブックマークアイコンから呼び出せます',
                '日付以外の項目がコピーされます',
                '金額未入力でもお気に入り登録可能です',
              ],
            ),
            _HelpSection(
              icon: Icons.account_balance,
              color: const Color(0xFF5856D6),
              title: '資産',
              items: const [
                '口座・残高（電子マネー等）・現金の3種類を管理できます',
                '残高タイプを選ぶと支払方法「残高払い」が自動で作成されます',
                '取引の登録に応じて残高が自動で更新されます',
              ],
            ),
            _HelpSection(
              icon: Icons.payment,
              color: const Color(0xFFFF2D55),
              title: '支払方法',
              items: const [
                '現金・即時、クレジットカード、残高払い、その他から選べます',
                'クレジットカードは締め日・引落日・引落月を設定できます',
                '各支払方法は資産と紐付けて残高を連動させます',
              ],
            ),
            _HelpSection(
              icon: Icons.category,
              color: const Color(0xFF00C7BE),
              title: 'カテゴリ',
              items: const [
                '食費・交通費など自由にカテゴリを作成できます',
                'ダッシュボードの支出内訳チャートに反映されます',
              ],
            ),
            _HelpSection(
              icon: Icons.credit_score,
              color: const Color(0xFFAF52DE),
              title: 'クレジット精算',
              items: const [
                'クレジットカードの未精算取引を一覧で確認できます',
                '月ごとにまとめて精算できます',
                '精算すると引落先の資産残高が更新されます',
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.dark_mode,
                        size: 28, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    const Text('ダークモード',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '右上のアイコンでライト/ダークモードを切り替えられます',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  const _HelpSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(
                                fontSize: 15, height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
