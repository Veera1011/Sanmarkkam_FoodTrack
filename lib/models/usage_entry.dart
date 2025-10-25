// models/usage_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UsageEntry {
  final String id;
  final String itemId;
  final double quantityUsed;
  final DateTime dateUsed;
  final double expense;

  UsageEntry({
    required this.id,
    required this.itemId,
    required this.quantityUsed,
    required this.dateUsed,
    required this.expense,
  });

  factory UsageEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UsageEntry(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      quantityUsed: (data['quantityUsed'] ?? 0).toDouble(),
      dateUsed: (data['dateUsed'] as Timestamp).toDate(),
      expense: (data['expense'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'quantityUsed': quantityUsed,
      'dateUsed': Timestamp.fromDate(dateUsed),
      'expense': expense,
    };
  }
}