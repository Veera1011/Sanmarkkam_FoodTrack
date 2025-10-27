import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/usage_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get user's items collection reference
  CollectionReference _itemsCollection(String userId) {
    return _db.collection('users').doc(userId).collection('items');
  }

  // Get user's usage collection reference
  CollectionReference _usageCollection(String userId) {
    return _db.collection('users').doc(userId).collection('usage');
  }

  // Add new food item
  Future<void> addItem(String userId, FoodItem item) async {
    await _itemsCollection(userId).add(item.toMap());
  }

  // Update existing food item
  Future<void> updateItem(String userId, FoodItem item) async {
    await _itemsCollection(userId).doc(item.id).update(item.toMap());
  }

  // Get all items stream
  Stream<List<FoodItem>> getItems(String userId) {
    return _itemsCollection(userId)
        .orderBy('datePurchased', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FoodItem.fromFirestore(doc))
        .toList());
  }

  // Add usage entry
  Future<void> addUsage(String userId, UsageEntry usage) async {
    await _usageCollection(userId).add(usage.toMap());
  }

  // Get all usage entries stream
  Stream<List<UsageEntry>> getUsage(String userId) {
    return _usageCollection(userId)
        .orderBy('dateUsed', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UsageEntry.fromFirestore(doc))
        .toList());
  }

  // Get usage for specific item
  Stream<List<UsageEntry>> getUsageForItem(String userId, String itemId) {
    return _usageCollection(userId)
        .where('itemId', isEqualTo: itemId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UsageEntry.fromFirestore(doc))
        .toList());
  }

  // Get today's usage
  Stream<List<UsageEntry>> getTodaysUsage(String userId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateUsed', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UsageEntry.fromFirestore(doc))
        .toList());
  }

  // Get usage for a date range
  Stream<List<UsageEntry>> getUsageByDateRange(
      String userId,
      DateTime startDate,
      DateTime endDate,
      ) {
    print('🔍 Querying usage from $startDate to $endDate');

    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(endDate);

    print('📅 Start timestamp: $startTimestamp');
    print('📅 End timestamp: $endTimestamp');

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: startTimestamp)
        .where('dateUsed', isLessThanOrEqualTo: endTimestamp)
        .orderBy('dateUsed', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📦 Found ${snapshot.docs.length} usage entries in date range');

      final entries = snapshot.docs.map((doc) {
        try {
          final entry = UsageEntry.fromFirestore(doc);
          print('📊 Entry: ${entry.dateUsed} - ${entry.expense}');
          return entry;
        } catch (e) {
          print('❌ Error parsing document ${doc.id}: $e');
          print('Document data: ${doc.data()}');
          rethrow;
        }
      }).toList();

      entries.sort((a, b) => b.dateUsed.compareTo(a.dateUsed));

      return entries;
    });
  }

  // Calculate remaining quantity for an item
  Future<double> getRemainingQuantity(String userId, String itemId) async {
    final itemDoc = await _itemsCollection(userId).doc(itemId).get();
    if (!itemDoc.exists) return 0;

    final item = FoodItem.fromFirestore(itemDoc);

    final usageSnapshot = await _usageCollection(userId)
        .where('itemId', isEqualTo: itemId)
        .get();

    final totalUsed = usageSnapshot.docs.fold<double>(
      0,
          (sum, doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return sum;
        final quantityUsed = (data['quantityUsed'] ?? 0) as num;
        return sum + quantityUsed.toDouble();
      },
    );

    return item.quantityPurchased - totalUsed;
  }
}