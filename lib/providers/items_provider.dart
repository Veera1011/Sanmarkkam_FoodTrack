// providers/items_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_item.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final itemsProvider = StreamProvider<List<FoodItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getItems(user.uid);
});

// Provider to get remaining quantity for each item
final itemRemainingQuantityProvider = FutureProvider.family<double, String>((ref, itemId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  return await ref.watch(firestoreServiceProvider).getRemainingQuantity(user.uid, itemId);
});
