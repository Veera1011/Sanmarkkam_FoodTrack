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

  // Add new food item (with duplication check)
  Future<void> addItem(String userId, FoodItem item) async {
    // Double-check for duplicates before adding
    final existing = await findMatchingItemForPurchase(
      userId,
      item.name,
      item.datePurchased,
      item.unitPrice,
    );

    if (existing != null) {
      throw Exception(
        'Duplicate item found: ${item.name} already exists for this month with same price. '
            'Please use the update function instead.',
      );
    }

    await _itemsCollection(userId).add(item.toMap());
  }

  // Update existing food item
  Future<void> updateItem(String userId, FoodItem item) async {
    await _itemsCollection(userId).doc(item.id).update(item.toMap());
  }

  // Add quantity to existing item (atomic operation)
  Future<void> addQuantityToItem(
      String userId,
      String itemId,
      double quantityToAdd,
      ) async {
    await _db.runTransaction((transaction) async {
      final itemRef = _itemsCollection(userId).doc(itemId);
      final snapshot = await transaction.get(itemRef);

      if (!snapshot.exists) {
        throw Exception('Item not found');
      }

      final item = FoodItem.fromFirestore(snapshot);

      if (item.isMonthClosed) {
        throw Exception('Cannot add quantity to closed month');
      }

      final newQuantity = item.quantityPurchased + quantityToAdd;
      transaction.update(itemRef, {'quantityPurchased': newQuantity});
    });
  }

  // Get all items stream
  Stream<List<FoodItem>> getItems(String userId) {
    return _itemsCollection(userId)
        .orderBy('datePurchased', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList());
  }

  // Add usage entry with validation
  Future<void> addUsage(String userId, UsageEntry usage) async {
    // Validate that item exists and has sufficient quantity
    final itemDoc = await _itemsCollection(userId).doc(usage.itemId).get();
    if (!itemDoc.exists) {
      throw Exception('Item not found');
    }

    final item = FoodItem.fromFirestore(itemDoc);

    if (item.isMonthClosed) {
      throw Exception('Cannot add usage to a closed month');
    }

    final remaining = await getRemainingQuantity(userId, usage.itemId);
    if (usage.quantityUsed > remaining) {
      throw Exception(
        'Insufficient quantity. Available: ${remaining.toStringAsFixed(2)} kg',
      );
    }

    await _usageCollection(userId).add(usage.toMap());
  }

  // Get all usage entries stream
  Stream<List<UsageEntry>> getUsage(String userId) {
    return _usageCollection(userId)
        .orderBy('dateUsed', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => UsageEntry.fromFirestore(doc)).toList());
  }

  // Get usage for specific item
  Stream<List<UsageEntry>> getUsageForItem(String userId, String itemId) {
    return _usageCollection(userId)
        .where('itemId', isEqualTo: itemId)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => UsageEntry.fromFirestore(doc)).toList());
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
        .map((snapshot) =>
        snapshot.docs.map((doc) => UsageEntry.fromFirestore(doc)).toList());
  }

  // Get usage for a date range
  Stream<List<UsageEntry>> getUsageByDateRange(
      String userId,
      DateTime startDate,
      DateTime endDate,
      ) {
    final normalizedStart =
    DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final normalizedEnd =
    DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final startTimestamp = Timestamp.fromDate(normalizedStart);
    final endTimestamp = Timestamp.fromDate(normalizedEnd);

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: startTimestamp)
        .where('dateUsed', isLessThanOrEqualTo: endTimestamp)
        .orderBy('dateUsed', descending: true)
        .snapshots()
        .map((snapshot) {
      final entries =
      snapshot.docs.map((doc) => UsageEntry.fromFirestore(doc)).toList();
      entries.sort((a, b) => b.dateUsed.compareTo(a.dateUsed));
      return entries;
    });
  }

  // Calculate remaining quantity for an item
  Future<double> getRemainingQuantity(String userId, String itemId) async {
    final itemDoc = await _itemsCollection(userId).doc(itemId).get();
    if (!itemDoc.exists) return 0;

    final item = FoodItem.fromFirestore(itemDoc);

    final usageSnapshot =
    await _usageCollection(userId).where('itemId', isEqualTo: itemId).get();

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

  // Close month for an item and carry forward remaining stock (with transaction)
  Future<String?> closeMonthForItem(String userId, String itemId) async {
    return await _db.runTransaction<String?>((transaction) async {
      final itemRef = _itemsCollection(userId).doc(itemId);
      final itemDoc = await transaction.get(itemRef);

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

      // Mark original item as closed
      transaction.update(itemRef, {'isMonthClosed': true});

      if (remaining < 0.01) {
        // No stock to carry forward
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
        unitPrice: item.unitPrice,
        datePurchased: nextMonth,
        isCarriedForward: true,
        previousMonthItemId: itemId,
        isMonthClosed: false,
      );

      // Add carryforward item
      final newDocRef = _itemsCollection(userId).doc();
      transaction.set(newDocRef, carryForwardItem.toMap());

      print('✅ Month closed: ${item.name}');
      print('   Remaining: ${remaining.toStringAsFixed(2)} kg');
      print('   Carried to: ${nextMonth.year}-${nextMonth.month}');

      return newDocRef.id;
    });
  }

  // Check if item can accept more stock (same name, same month, same price)
  Future<FoodItem?> findMatchingItemForPurchase(
      String userId,
      String name,
      DateTime purchaseDate,
      double unitPrice,
      ) async {
    final startOfMonth = DateTime(purchaseDate.year, purchaseDate.month, 1);
    final endOfMonth =
    DateTime(purchaseDate.year, purchaseDate.month + 1, 0, 23, 59, 59);

    final snapshot = await _itemsCollection(userId)
        .where('name', isEqualTo: name)
        .where('datePurchased',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('datePurchased',
        isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    for (var doc in snapshot.docs) {
      final item = FoodItem.fromFirestore(doc);

      // Check if price matches (within 0.01 tolerance)
      final isSamePrice = (item.unitPrice - unitPrice).abs() < 0.01;

      // Check if not closed
      if (isSamePrice && !item.isMonthClosed) {
        return item;
      }
    }

    return null;
  }

  // Get items by month
  Future<List<FoodItem>> getItemsByMonth(String userId, DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final snapshot = await _itemsCollection(userId)
        .where('datePurchased',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('datePurchased',
        isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    return snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
  }

  // Get unclosed items for a month
  Future<List<FoodItem>> getUnclosedItemsForMonth(
      String userId, DateTime month) async {
    final items = await getItemsByMonth(userId, month);
    return items.where((item) => !item.isMonthClosed).toList();
  }

  // Get previous month item details (for carryforward tracking)
  Future<FoodItem?> getPreviousMonthItem(
      String userId, String previousMonthItemId) async {
    try {
      final doc = await _itemsCollection(userId).doc(previousMonthItemId).get();
      if (doc.exists) {
        return FoodItem.fromFirestore(doc);
      }
    } catch (e) {
      print('Error fetching previous month item: $e');
    }
    return null;
  }

  // Delete item (only if not closed and no usage)
  Future<void> deleteItem(String userId, String itemId) async {
    final item = await _itemsCollection(userId).doc(itemId).get();
    if (!item.exists) {
      throw Exception('Item not found');
    }

    final itemData = FoodItem.fromFirestore(item);
    if (itemData.isMonthClosed) {
      throw Exception('Cannot delete closed month items');
    }

    // Check if there's any usage
    final usageSnapshot = await _usageCollection(userId)
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .get();

    if (usageSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete item with usage history');
    }

    await _itemsCollection(userId).doc(itemId).delete();
  }
}
