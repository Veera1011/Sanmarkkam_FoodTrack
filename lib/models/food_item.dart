// models/food_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final double quantityPurchased;
  final double unitPrice;
  final DateTime datePurchased;

  FoodItem({
    required this.id,
    required this.name,
    required this.quantityPurchased,
    required this.unitPrice,
    required this.datePurchased,
  });

  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantityPurchased: (data['quantityPurchased'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      datePurchased: (data['datePurchased'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantityPurchased': quantityPurchased,
      'unitPrice': unitPrice,
      'datePurchased': Timestamp.fromDate(datePurchased),
    };
  }
}

