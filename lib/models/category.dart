import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      sortOrder: (data['sortOrder'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sortOrder': sortOrder,
    };
  }
}
