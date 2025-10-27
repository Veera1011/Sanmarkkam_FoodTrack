import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/usage_provider.dart';
import '../../models/food_item.dart';
import '../../models/usage_entry.dart';
import '../../widgets/item_card.dart';
import '../items/add_item_screen.dart';
import '../usage/add_usage_screen.dart';
import '../expenses/expense_summary_screen.dart';

enum DashboardPeriod { today, thisMonth, thisYear, custom, all }

// Provider for selected dashboard period
final dashboardPeriodProvider = StateProvider<DashboardPeriod>((ref) => DashboardPeriod.thisMonth);

// Provider for custom date range
final dashboardCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Provider for filtered items
final filteredItemsProvider = Provider<AsyncValue<List<FoodItem>>>((ref) {
  final period = ref.watch(dashboardPeriodProvider);
  final customRange = ref.watch(dashboardCustomRangeProvider);
  final itemsAsync = ref.watch(itemsProvider);

  return itemsAsync.when(
    data: (items) {
      final filtered = _filterItemsByPeriod(items, period, customRange);
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

// Provider for filtered usage/expenses
final filteredExpensesProvider = Provider<AsyncValue<double>>((ref) {
  final period = ref.watch(dashboardPeriodProvider);
  final customRange = ref.watch(dashboardCustomRangeProvider);
  final usageAsync = ref.watch(usageProvider);

  return usageAsync.when(
    data: (entries) {
      final filtered = _filterUsageByPeriod(entries, period, customRange);
      final total = filtered.fold<double>(0.0, (sum, entry) => sum + entry.expense);
      return AsyncValue.data(total);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

List<FoodItem> _filterItemsByPeriod(
    List<FoodItem> items,
    DashboardPeriod period,
    DateTimeRange? customRange,
    ) {
  if (period == DashboardPeriod.all) return items;

  final now = DateTime.now();
  DateTime startDate;
  DateTime endDate;

  switch (period) {
    case DashboardPeriod.today:
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DashboardPeriod.thisMonth:
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      break;
    case DashboardPeriod.thisYear:
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, 12, 31, 23, 59, 59);
      break;
    case DashboardPeriod.custom:
      if (customRange == null) return items;
      startDate = customRange.start;
      endDate = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
      break;
    case DashboardPeriod.all:
      return items;
  }

  return items.where((item) {
    return item.datePurchased.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        item.datePurchased.isBefore(endDate.add(const Duration(seconds: 1)));
  }).toList();
}

List<UsageEntry> _filterUsageByPeriod(
    List<UsageEntry> entries,
    DashboardPeriod period,
    DateTimeRange? customRange,
    ) {
  if (period == DashboardPeriod.all) return entries;

  final now = DateTime.now();
  DateTime startDate;
  DateTime endDate;

  switch (period) {
    case DashboardPeriod.today:
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DashboardPeriod.thisMonth:
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      break;
    case DashboardPeriod.thisYear:
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, 12, 31, 23, 59, 59);
      break;
    case DashboardPeriod.custom:
      if (customRange == null) return entries;
      startDate = customRange.start;
      endDate = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
      break;
    case DashboardPeriod.all:
      return entries;
  }

  return entries.where((entry) {
    return entry.dateUsed.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        entry.dateUsed.isBefore(endDate.add(const Duration(seconds: 1)));
  }).toList();
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredItemsAsync = ref.watch(filteredItemsProvider);
    final filteredExpensesAsync = ref.watch(filteredExpensesProvider);
    final selectedPeriod = ref.watch(dashboardPeriodProvider);
    final customRange = ref.watch(dashboardCustomRangeProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/sanmarkkam-logo1.png',
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text('FoodTrack'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'View Analytics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpenseSummaryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Period Filter Card
          _buildPeriodFilter(context, ref, selectedPeriod, customRange),

          // Expense Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: filteredExpensesAsync.when(
              data: (expense) => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPeriodLabel(selectedPeriod, customRange),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(expense),
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.currency_rupee,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ExpenseSummaryScreen()),
                      );
                    },
                    icon: const Icon(Icons.insights),
                    label: const Text('View Detailed Analytics'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error: $e'),
            ),
          ),

          // Header with Add Usage Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      filteredItemsAsync.when(
                        data: (items) => Text(
                          '${items.length} item${items.length == 1 ? '' : 's'} in ${_getPeriodLabel(selectedPeriod, customRange)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        loading: () => const SizedBox(),
                        error: (e, s) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddUsageScreen()),
                    );
                  },
                  icon: const Icon(Icons.remove, size: 20),
                  label: const Text('Add Usage'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: filteredItemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items in ${_getPeriodLabel(selectedPeriod, customRange).toLowerCase()}',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedPeriod == DashboardPeriod.all
                              ? 'Add your first item to start tracking'
                              : 'Try selecting a different time period',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AddItemScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(itemsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return ItemCard(item: items[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(itemsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddItemScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildPeriodFilter(
      BuildContext context,
      WidgetRef ref,
      DashboardPeriod selectedPeriod,
      DateTimeRange? customRange,
      ) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filter by Period',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip(
                    context,
                    ref,
                    'Today',
                    DashboardPeriod.today,
                    Icons.today,
                    selectedPeriod,
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    context,
                    ref,
                    'This Month',
                    DashboardPeriod.thisMonth,
                    Icons.calendar_month,
                    selectedPeriod,
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    context,
                    ref,
                    'This Year',
                    DashboardPeriod.thisYear,
                    Icons.calendar_today,
                    selectedPeriod,
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    context,
                    ref,
                    'Custom',
                    DashboardPeriod.custom,
                    Icons.date_range,
                    selectedPeriod,
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: customRange,
                      );
                      if (picked != null) {
                        ref.read(dashboardCustomRangeProvider.notifier).state = picked;
                        ref.read(dashboardPeriodProvider.notifier).state = DashboardPeriod.custom;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodChip(
                    context,
                    ref,
                    'All Time',
                    DashboardPeriod.all,
                    Icons.all_inclusive,
                    selectedPeriod,
                  ),
                ],
              ),
            ),
            if (selectedPeriod == DashboardPeriod.custom && customRange != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(customRange.start)} - ${DateFormat('dd MMM yyyy').format(customRange.end)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(
      BuildContext context,
      WidgetRef ref,
      String label,
      DashboardPeriod period,
      IconData icon,
      DashboardPeriod selectedPeriod,
      {VoidCallback? onTap}
      ) {
    final isSelected = selectedPeriod == period;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (onTap != null) {
          onTap();
        } else {
          ref.read(dashboardPeriodProvider.notifier).state = period;
        }
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700],
      ),
    );
  }

  String _getPeriodLabel(DashboardPeriod period, DateTimeRange? customRange) {
    switch (period) {
      case DashboardPeriod.today:
        return 'Today\'s Expense';
      case DashboardPeriod.thisMonth:
        return '${DateFormat('MMMM yyyy').format(DateTime.now())} Expense';
      case DashboardPeriod.thisYear:
        return '${DateTime.now().year} Expense';
      case DashboardPeriod.custom:
        if (customRange == null) return 'Custom Period Expense';
        return 'Custom Period Expense';
      case DashboardPeriod.all:
        return 'Total Expense (All Time)';
    }
  }
}