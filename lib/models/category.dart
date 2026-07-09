import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoryType { expense, income }

class Category {
  final String id;
  final String name;
  final CategoryType type;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    this.type = CategoryType.expense,
    this.sortOrder = 0,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeStr = data['type'] as String?;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      type: typeStr == 'income' ? CategoryType.income : CategoryType.expense,
      sortOrder: (data['sortOrder'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type == CategoryType.income ? 'income' : 'expense',
      'sortOrder': sortOrder,
    };
  }
}
