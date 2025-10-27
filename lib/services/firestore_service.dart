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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);

    print('📅 Today\'s date range: $today to $tomorrow');

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('dateUsed', isLessThan: Timestamp.fromDate(tomorrow))
        .snapshots()
        .map((snapshot) {
      print('📦 Today\'s usage: Found ${snapshot.docs.length} entries');
      return snapshot.docs
          .map((doc) => UsageEntry.fromFirestore(doc))
          .toList();
    });
  }

  // Get usage for a date range
  Stream<List<UsageEntry>> getUsageByDateRange(
      String userId,
      DateTime startDate,
      DateTime endDate,
      ) {
    // Ensure we're using UTC or normalize the dates
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    print('🔍 Querying usage from $normalizedStart to $normalizedEnd');
    print('📅 Device time: ${DateTime.now()}');

    final startTimestamp = Timestamp.fromDate(normalizedStart);
    final endTimestamp = Timestamp.fromDate(normalizedEnd);

    print('📅 Start timestamp: $startTimestamp (${startTimestamp.toDate()})');
    print('📅 End timestamp: $endTimestamp (${endTimestamp.toDate()})');

    return _usageCollection(userId)
        .where('dateUsed', isGreaterThanOrEqualTo: startTimestamp)
        .where('dateUsed', isLessThanOrEqualTo: endTimestamp)
        .orderBy('dateUsed', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📦 Found ${snapshot.docs.length} usage entries in date range');

      if (snapshot.docs.isEmpty) {
        print('⚠️ No documents found. Checking all usage entries...');
        // This will help debug - you can remove this later
        _usageCollection(userId).get().then((allDocs) {
          print('📊 Total usage entries in database: ${allDocs.docs.length}');
          if (allDocs.docs.isNotEmpty) {
            print('📊 Sample dates from database:');
            for (var doc in allDocs.docs.take(5)) {
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['dateUsed'] as Timestamp;
              print('   - ${timestamp.toDate()}');
            }
          }
        });
      }

      final entries = snapshot.docs.map((doc) {
        try {
          final entry = UsageEntry.fromFirestore(doc);
          print('📊 Entry: ${entry.dateUsed} - ₹${entry.expense}');
          return entry;
        } catch (e) {
          print('❌ Error parsing document ${doc.id}: $e');
          print('Document data: ${doc.data()}');
          rethrow;
        }
      }).toList();

      // Sort by date (most recent first)
      entries.sort((a, b) => b.dateUsed.compareTo(a.dateUsed));

      return entries;
    });
  }

  // Calculate remaining quantity for an item (considers same month usage only)
  Future<double> getRemainingQuantity(String userId, String itemId) async {
    final itemDoc = await _itemsCollection(userId).doc(itemId).get();
    if (!itemDoc.exists) return 0;

    final item = FoodItem.fromFirestore(itemDoc);

    // Get all usage entries for this item
    final usageSnapshot = await _usageCollection(userId)
        .where('itemId', isEqualTo: itemId)
        .get();

    // Only count usage from the same month as the item's purchase date
    final totalUsed = usageSnapshot.docs.fold<double>(
      0,
          (sum, doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return sum;

        // Check if usage is in the same month as item purchase
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

    final remaining = item.quantityPurchased - totalUsed;
    print('📊 getRemainingQuantity for ${item.name}:');
    print('   Purchase month: ${item.datePurchased.year}-${item.datePurchased.month}');
    print('   Purchased: ${item.quantityPurchased} kg');
    print('   Used (same month): $totalUsed kg');
    print('   Remaining: $remaining kg');

    return remaining;
  }

  // Helper method to get remaining quantity for display (same as above)
  Future<double> getRemainingQuantityForMonth(String userId, String itemId) async {
    return getRemainingQuantity(userId, itemId);
  }
}