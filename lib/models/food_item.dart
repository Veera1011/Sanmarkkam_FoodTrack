// models/food_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final double quantityPurchased;
  final double unitPrice;
  final DateTime datePurchased;
  final bool
  isCarriedForward; // New: Track if this is carried from previous month
  final String? previousMonthItemId; // New: Link to previous month's item
  final bool isMonthClosed; // New: Track if month is closed for this item

  FoodItem({
    required this.id,
    required this.name,
    required this.quantityPurchased,
    required this.unitPrice,
    required this.datePurchased,
    this.isCarriedForward = false,
    this.previousMonthItemId,
    this.isMonthClosed = false,
  });

  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantityPurchased: (data['quantityPurchased'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      datePurchased: (data['datePurchased'] as Timestamp).toDate(),
      isCarriedForward: data['isCarriedForward'] ?? false,
      previousMonthItemId: data['previousMonthItemId'],
      isMonthClosed: data['isMonthClosed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantityPurchased': quantityPurchased,
      'unitPrice': unitPrice,
      'datePurchased': Timestamp.fromDate(datePurchased),
      'isCarriedForward': isCarriedForward,
      'previousMonthItemId': previousMonthItemId,
      'isMonthClosed': isMonthClosed,
    };
  }

  FoodItem copyWith({
    String? id,
    String? name,
    double? quantityPurchased,
    double? unitPrice,
    DateTime? datePurchased,
    bool? isCarriedForward,
    String? previousMonthItemId,
    bool? isMonthClosed,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantityPurchased: quantityPurchased ?? this.quantityPurchased,
      unitPrice: unitPrice ?? this.unitPrice,
      datePurchased: datePurchased ?? this.datePurchased,
      isCarriedForward: isCarriedForward ?? this.isCarriedForward,
      previousMonthItemId: previousMonthItemId ?? this.previousMonthItemId,
      isMonthClosed: isMonthClosed ?? this.isMonthClosed,
    );
  }
}
