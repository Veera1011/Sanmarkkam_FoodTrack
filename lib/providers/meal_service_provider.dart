// lib/providers/meal_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_service.dart';
import 'auth_provider.dart';
import 'items_provider.dart';
import '../providers/usage_provider.dart';

final mealServicesProvider = StreamProvider<List<MealService>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getMealServices(user.uid);
});

final todaysMealServicesProvider = StreamProvider<List<MealService>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getTodaysMealServices(user.uid);
});

// Provider for date range meal services
final dateRangeMealServicesProvider =
StreamProvider.family<List<MealService>, DateRange>((ref, dateRange) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getMealServicesByDateRange(
    user.uid,
    dateRange.start,
    dateRange.end,
  );
});

// Provider for today's total people served
final todaysTotalPeopleProvider = Provider<int>((ref) {
  final todaysMeals = ref.watch(todaysMealServicesProvider);

  return todaysMeals.when(
    data: (meals) {
      if (meals.isEmpty) return 0;
      return meals.fold<int>(0, (sum, meal) => sum + meal.numberOfPeople);
    },
    loading: () => 0,
    error: (err, stack) {
      print('Error calculating today\'s people: $err');
      return 0;
    },
  );
});
