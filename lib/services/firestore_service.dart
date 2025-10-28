import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/usage_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _itemsCollection(String userId) {
    return _db.collection('users').doc(userId).collection('items');
  }

  CollectionReference _usageCollection(String userId) {
    return _db.collection('users').doc(userId).collection('usage');
  }

  // Add new food item (now checks for price differences)
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('dateUsed', isLessThan: Timestamp.fromDate(tomorrow))
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
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final startTimestamp = Timestamp.fromDate(normalizedStart);
    final endTimestamp = Timestamp.fromDate(normalizedEnd);

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: startTimestamp)
        .where('dateUsed', isLessThanOrEqualTo: endTimestamp)
        .orderBy('dateUsed', descending: true)
        .snapshots()
        .map((snapshot) {
      final entries = snapshot.docs.map((doc) => UsageEntry.fromFirestore(doc)).toList();
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

        final usageTimestamp = data['dateUsed'] as Timestamp;
        final usageDate = usageTimestamp.toDate();

        final isSameMonth = item.datePurchased.year == usageDate.year &&
            item.datePurchased.month == usageDate.month;

        if (isSameMonth) {
          final quantityUsed = (data['quantityUsed'] ?? 0) as num;
          return sum + quantityUsed.toDouble();
        }

        return sum;
      },
    );

    return item.quantityPurchased - totalUsed;
  }

  // New: Close month for an item and carry forward remaining stock
  Future<String?> closeMonthForItem(String userId, String itemId) async {
    try {
      final itemDoc = await _itemsCollection(userId).doc(itemId).get();
      if (!itemDoc.exists) {
        throw Exception('Item not found');
      }

      final item = FoodItem.fromFirestore(itemDoc);

      // Check if already closed
      if (item.isMonthClosed) {
        throw Exception('This month is already closed for this item');
      }

      // Calculate remaining quantity
      final remaining = await getRemainingQuantity(userId, itemId);

      if (remaining < 0.01) {
        // No stock to carry forward, just mark as closed
        await _itemsCollection(userId).doc(itemId).update({
          'isMonthClosed': true,
        });
        return null;
      }

      // Create next month's entry with carryforward
      final currentDate = item.datePurchased;
      final nextMonth = DateTime(
        currentDate.month == 12 ? currentDate.year + 1 : currentDate.year,
        currentDate.month == 12 ? 1 : currentDate.month + 1,
        1, // First day of next month
      );

      final carryForwardItem = FoodItem(
        id: '',
        name: item.name,
        quantityPurchased: remaining,
        unitPrice: item.unitPrice, // Carry same price
        datePurchased: nextMonth,
        isCarriedForward: true,
        previousMonthItemId: itemId,
        isMonthClosed: false,
      );

      // Add carryforward item
      final newDocRef = await _itemsCollection(userId).add(carryForwardItem.toMap());

      // Mark original item as closed
      await _itemsCollection(userId).doc(itemId).update({
        'isMonthClosed': true,
      });

      print('✅ Month closed: ${item.name}');
      print('   Remaining: ${remaining.toStringAsFixed(2)} kg');
      print('   Carried to: ${nextMonth.year}-${nextMonth.month}');

      return newDocRef.id; // Return new item ID
    } catch (e) {
      print('❌ Error closing month: $e');
      rethrow;
    }
  }

  // New: Check if item can accept more stock (same name, same month, same price)
  Future<FoodItem?> findMatchingItemForPurchase(
      String userId,
      String name,
      DateTime purchaseDate,
      double unitPrice,
      ) async {
    final snapshot = await _itemsCollection(userId)
        .where('name', isEqualTo: name)
        .get();

    for (var doc in snapshot.docs) {
      final item = FoodItem.fromFirestore(doc);

      // Check same month and year
      final isSameMonth = item.datePurchased.year == purchaseDate.year &&
          item.datePurchased.month == purchaseDate.month;

      // Check if price matches (within 0.01 tolerance)
      final isSamePrice = (item.unitPrice - unitPrice).abs() < 0.01;

      // Check if not closed
      if (isSameMonth && isSamePrice && !item.isMonthClosed) {
        return item;
      }
    }

    return null;
  }

  // New: Get items by month
  Future<List<FoodItem>> getItemsByMonth(String userId, DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final snapshot = await _itemsCollection(userId)
        .where('datePurchased', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('datePurchased', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    return snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
  }

  // New: Get unclosed items for a month
  Future<List<FoodItem>> getUnclosedItemsForMonth(String userId, DateTime month) async {
    final items = await getItemsByMonth(userId, month);
    return items.where((item) => !item.isMonthClosed).toList();
  }

  // Helper
  Future<double> getRemainingQuantityForMonth(String userId, String itemId) async {
    return getRemainingQuantity(userId, itemId);
  }
}