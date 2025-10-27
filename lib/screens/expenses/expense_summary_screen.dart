import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/usage_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/usage_entry.dart';
import '../../models/food_item.dart';
import '../../widgets/expense_chart.dart';
import '../../widgets/product_expense_chart.dart';

enum ExpensePeriod { day, month, year, custom }

class ExpenseSummaryScreen extends ConsumerStatefulWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  ConsumerState<ExpenseSummaryScreen> createState() => _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends ConsumerState<ExpenseSummaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateRange _getDateRangeForPeriod(ExpensePeriod period) {
    final now = _selectedDate;

    switch (period) {
      case ExpensePeriod.day:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        print('📅 Day range: $start to $end');
        return DateRange(start, end);

      case ExpensePeriod.month:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        print('📅 Month range: $start to $end');
        return DateRange(start, end);

      case ExpensePeriod.year:
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        print('📅 Year range: $start to $end');
        return DateRange(start, end);

      case ExpensePeriod.custom:
        final start = DateTime(_customStartDate.year, _customStartDate.month, _customStartDate.day, 0, 0, 0);
        final end = DateTime(_customEndDate.year, _customEndDate.month, _customEndDate.day, 23, 59, 59, 999);
        print('📅 Custom range: $start to $end');
        return DateRange(start, end);
    }
  }

  Future<void> _selectDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectMonth() async {
    await showDialog(
      context: context,
      builder: (context) => _MonthYearPicker(
        initialDate: _selectedDate,
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
        },
      ),
    );
  }

  Future<void> _selectYear() async {
    await showDialog(
      context: context,
      builder: (context) => _YearPicker(
        initialYear: _selectedDate.year,
        onYearSelected: (year) {
          setState(() => _selectedDate = DateTime(year, _selectedDate.month, _selectedDate.day));
        },
      ),
    );
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _customStartDate, end: _customEndDate),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Day'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Month'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Year'),
            Tab(icon: Icon(Icons.date_range), text: 'Custom'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpenseView(ExpensePeriod.day),
          _buildExpenseView(ExpensePeriod.month),
          _buildExpenseView(ExpensePeriod.year),
          _buildExpenseView(ExpensePeriod.custom),
        ],
      ),
    );
  }

  Widget _buildExpenseView(ExpensePeriod period) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Center(child: Text('Please log in to view expenses'));
    }

    final dateRange = _getDateRangeForPeriod(period);
    final usageAsync = ref.watch(dateRangeUsageProvider(dateRange));
    final itemsAsync = ref.watch(itemsProvider);

    return Column(
      children: [
        _buildDateSelector(period),
        Expanded(
          child: usageAsync.when(
            data: (entries) {
              print('✅ Loaded ${entries.length} entries for display');
              return itemsAsync.when(
                data: (items) => _buildExpenseContent(entries, items, period, dateRange),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error loading items: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading expenses: $e'),
                  const SizedBox(height: 8),
                  Text('Stack: $s', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(ExpensePeriod period) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMMM yyyy');
    final yearFormat = DateFormat('yyyy');

    String displayText;
    VoidCallback onTap;

    switch (period) {
      case ExpensePeriod.day:
        displayText = dateFormat.format(_selectedDate);
        onTap = _selectDay;
        break;
      case ExpensePeriod.month:
        displayText = monthFormat.format(_selectedDate);
        onTap = _selectMonth;
        break;
      case ExpensePeriod.year:
        displayText = yearFormat.format(_selectedDate);
        onTap = _selectYear;
        break;
      case ExpensePeriod.custom:
        displayText = '${dateFormat.format(_customStartDate)} - ${dateFormat.format(_customEndDate)}';
        onTap = _selectCustomRange;
        break;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: Text(
          displayText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_calendar),
          onPressed: onTap,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildExpenseContent(
      List<UsageEntry> entries,
      List<FoodItem> items,
      ExpensePeriod period,
      DateRange dateRange,
      ) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No expenses in this period', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different date range',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final summary = _calculateSummary(entries, items, period);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dateRangeUsageProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCards(summary),
          const SizedBox(height: 16),
          _buildDailyTrendChart(summary, period),
          const SizedBox(height: 16),
          _buildProductWiseExpenseChart(summary),
          const SizedBox(height: 16),
          _buildProductExpenseList(summary),
          const SizedBox(height: 16),
          _buildTransactionsList(entries, items),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateSummary(
      List<UsageEntry> entries,
      List<FoodItem> items,
      ExpensePeriod period,
      ) {
    final totalExpense = entries.fold<double>(0, (sum, e) => sum + e.expense);

    // Product-wise expenses
    final Map<String, Map<String, dynamic>> productExpenses = {};
    for (final entry in entries) {
      final item = items.firstWhere((i) => i.id == entry.itemId, orElse: () => FoodItem(
        id: entry.itemId,
        name: 'Unknown Item',
        quantityPurchased: 0,
        unitPrice: 0,
        datePurchased: DateTime.now(),
      ));

      if (!productExpenses.containsKey(item.id)) {
        productExpenses[item.id] = {
          'name': item.name,
          'totalExpense': 0.0,
          'totalQuantity': 0.0,
          'entries': <UsageEntry>[],
        };
      }

      productExpenses[item.id]!['totalExpense'] =
          (productExpenses[item.id]!['totalExpense'] as double) + entry.expense;
      productExpenses[item.id]!['totalQuantity'] =
          (productExpenses[item.id]!['totalQuantity'] as double) + entry.quantityUsed;
      (productExpenses[item.id]!['entries'] as List<UsageEntry>).add(entry);
    }

    // Daily expenses for trend chart - use proper date formatting
    final Map<String, double> dailyExpenses = {};
    for (final entry in entries) {
      // Create a normalized date key (without time component)
      final date = DateTime(entry.dateUsed.year, entry.dateUsed.month, entry.dateUsed.day);
      final dateKey = DateFormat('dd MMM').format(date);
      dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0) + entry.expense;
    }

    // Sort daily expenses by date
    final sortedEntries = dailyExpenses.entries.toList();
    // Parse dates back for sorting
    sortedEntries.sort((a, b) {
      try {
        final dateA = DateFormat('dd MMM').parse(a.key);
        final dateB = DateFormat('dd MMM').parse(b.key);
        return dateA.compareTo(dateB);
      } catch (e) {
        return a.key.compareTo(b.key);
      }
    });
    final sortedDailyExpenses = Map.fromEntries(sortedEntries);

    final avgExpense = dailyExpenses.isEmpty ? 0.0 : totalExpense / dailyExpenses.length;
    final maxExpense = dailyExpenses.values.isEmpty ? 0.0 : dailyExpenses.values.reduce((a, b) => a > b ? a : b);

    print('💰 Summary calculated:');
    print('   Total: ₹$totalExpense');
    print('   Transactions: ${entries.length}');
    print('   Daily entries: ${dailyExpenses.length}');
    print('   Products: ${productExpenses.length}');

    return {
      'totalExpense': totalExpense,
      'totalTransactions': entries.length,
      'productExpenses': productExpenses,
      'dailyExpenses': sortedDailyExpenses,
      'averageExpense': avgExpense,
      'maxDailyExpense': maxExpense,
    };
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'Total Expense',
          currencyFormat.format(summary['totalExpense']),
          Icons.currency_rupee,
          Colors.green,
        ),
        _buildSummaryCard(
          'Transactions',
          summary['totalTransactions'].toString(),
          Icons.receipt,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Avg Daily',
          currencyFormat.format(summary['averageExpense']),
          Icons.trending_up,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Max Daily',
          currencyFormat.format(summary['maxDailyExpense']),
          Icons.leaderboard,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart(Map<String, dynamic> summary, ExpensePeriod period) {
    final dailyExpenses = summary['dailyExpenses'] as Map<String, double>;

    if (dailyExpenses.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Daily Expense Trend',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: ExpenseChart(dailyExpenses: dailyExpenses),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductWiseExpenseChart(Map<String, dynamic> summary) {
    final productExpenses = summary['productExpenses'] as Map<String, Map<String, dynamic>>;

    if (productExpenses.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Product-wise Distribution',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: ProductExpenseChart(productExpenses: productExpenses),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductExpenseList(Map<String, dynamic> summary) {
    final productExpenses = summary['productExpenses'] as Map<String, Map<String, dynamic>>;
    final sortedProducts = productExpenses.entries.toList()
      ..sort((a, b) => (b.value['totalExpense'] as double).compareTo(a.value['totalExpense'] as double));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_basket, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Product Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedProducts.map((entry) {
              final data = entry.value;
              final currencyFormat = NumberFormat.currency(symbol: '₹');
              final percentage = (data['totalExpense'] / summary['totalExpense'] * 100).toStringAsFixed(1);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Text(
                          currencyFormat.format(data['totalExpense']),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.scale, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${data['totalQuantity'].toStringAsFixed(2)} kg',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.pie_chart, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '$percentage%',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: data['totalExpense'] / summary['totalExpense'],
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<UsageEntry> entries, List<FoodItem> items) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    // Sort entries by date (most recent first)
    final sortedEntries = List<UsageEntry>.from(entries)
      ..sort((a, b) => b.dateUsed.compareTo(a.dateUsed));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'All Transactions (${entries.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedEntries.map((entry) {
              final item = items.firstWhere(
                    (i) => i.id == entry.itemId,
                orElse: () => FoodItem(
                  id: entry.itemId,
                  name: 'Unknown Item',
                  quantityPurchased: 0,
                  unitPrice: 0,
                  datePurchased: DateTime.now(),
                ),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.fastfood, size: 20),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.quantityUsed.toStringAsFixed(2)} kg used'),
                      Text(
                        dateFormat.format(entry.dateUsed),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Text(
                    currencyFormat.format(entry.expense),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Month-Year Picker Dialog
class _MonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const _MonthYearPicker({
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Month'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => selectedYear--),
                ),
                Text(
                  selectedYear.toString(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => selectedYear++),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == selectedMonth;
                  return InkWell(
                    onTap: () => setState(() => selectedMonth = month),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM').format(DateTime(2000, month)),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onDateSelected(DateTime(selectedYear, selectedMonth));
            Navigator.pop(context);
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}

// Year Picker Dialog
class _YearPicker extends StatefulWidget {
  final int initialYear;
  final Function(int) onYearSelected;

  const _YearPicker({
    required this.initialYear,
    required this.onYearSelected,
  });

  @override
  State<_YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  late int selectedYear;
  final int startYear = 2020;
  late final int endYear;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialYear;
    endYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(endYear - startYear + 1, (index) => startYear + index);

    return AlertDialog(
      title: const Text('Select Year'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            final isSelected = year == selectedYear;
            return InkWell(
              onTap: () => setState(() => selectedYear = year),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    year.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onYearSelected(selectedYear);
            Navigator.pop(context);
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}