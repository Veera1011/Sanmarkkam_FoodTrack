
// providers/usage_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/usage_entry.dart';
import 'auth_provider.dart';
import 'items_provider.dart';

final usageProvider = StreamProvider<List<UsageEntry>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getUsage(user.uid);
});

final todaysUsageProvider = StreamProvider<List<UsageEntry>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getTodaysUsage(user.uid);
});

final todaysTotalExpenseProvider = Provider<double>((ref) {
  final todaysUsage = ref.watch(todaysUsageProvider);

  return todaysUsage.when(
    data: (entries) {
      if (entries.isEmpty) return 0;
      return entries.fold<double>(0.0, (sum, entry) => sum + entry.expense);
    },
    loading: () => 0,
    error: (err, stack) {
      print('Error calculating today\'s expense: $err');
      return 0;
    },
  );
});

// Provider for date range usage
final dateRangeUsageProvider = StreamProvider.family<List<UsageEntry>, DateRange>((ref, dateRange) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(firestoreServiceProvider).getUsageByDateRange(
    user.uid,
    dateRange.start,
    dateRange.end,
  );
});

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);
}