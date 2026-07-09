import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/category.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  final _nameController = TextEditingController();
  late final TabController _tabController;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  CategoryType get _currentType =>
      _tabController.index == 0 ? CategoryType.expense : CategoryType.income;

  Future<void> _addCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      await _service.addCategory(Category(
        id: '',
        name: name,
        type: _currentType,
      ));
      _nameController.clear();
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

  Future<void> _editCategory(Category category) async {
    final controller = TextEditingController(text: category.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリを編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
          style: const TextStyle(fontSize: 17),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(ctx, true),
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

    if (result == true && controller.text.trim().isNotEmpty) {
      await _service.updateCategory(Category(
        id: category.id,
        name: controller.text.trim(),
        type: category.type,
        sortOrder: category.sortOrder,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カテゴリを更新しました')),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${category.name}」を削除しますか？'),
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
      await _service.deleteCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${category.name}」を削除しました')),
        );
      }
    }
  }

  Widget _buildCategoryList(List<Category> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 追加フォーム
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'カテゴリ名',
                            hintText: '例: 食費、交通費',
                          ),
                          style: const TextStyle(fontSize: 17),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addCategory(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _adding ? null : _addCategory,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(80, 50),
                        ),
                        child: _adding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('追加'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // カテゴリ一覧
              if (categories.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (int i = 0; i < categories.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(categories[i].name,
                                    style: const TextStyle(fontSize: 17)),
                              ),
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 20,
                                      color: Color(0xFF8E8E93)),
                                  onPressed: () =>
                                      _editCategory(categories[i]),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Color(0xFFC7C7CC)),
                                  onPressed: () =>
                                      _deleteCategory(categories[i]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < categories.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Divider(),
                          ),
                      ],
                    ],
                  ),
                ),
              if (categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('カテゴリを追加してください',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey[500])),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出カテゴリ'),
            Tab(text: '収入カテゴリ'),
          ],
          onTap: (_) {
            // タブ切り替え時に入力欄をリセット
            _nameController.clear();
          },
        ),
        Expanded(
          child: StreamBuilder<List<Category>>(
            stream: _service.watchCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final expenseList =
                  all.where((c) => c.type == CategoryType.expense).toList();
              final incomeList =
                  all.where((c) => c.type == CategoryType.income).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoryList(expenseList),
                  _buildCategoryList(incomeList),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
