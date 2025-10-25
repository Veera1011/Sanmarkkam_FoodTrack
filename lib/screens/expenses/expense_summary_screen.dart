import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/usage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/expense_chart.dart';
import '../../models/usage_entry.dart';
import 'package:flutter/foundation.dart';

class ExpenseSummaryScreen extends ConsumerStatefulWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  ConsumerState<ExpenseSummaryScreen> createState() => _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends ConsumerState<ExpenseSummaryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  final List<String> _timeRanges = ['Last 7 days', 'Last 30 days', 'Last 90 days', 'Custom'];
  String _selectedTimeRange = 'Last 30 days';

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedTimeRange) {
      case 'Last 7 days':
        _startDate = now.subtract(const Duration(days: 6));
        break;
      case 'Last 30 days':
        _startDate = now.subtract(const Duration(days: 29));
        break;
      case 'Last 90 days':
        _startDate = now.subtract(const Duration(days: 89));
        break;
      default:
        _startDate = now.subtract(const Duration(days: 29));
    }
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedTimeRange = 'Custom';
      });
    }
  }

  void _onTimeRangeSelected(String? value) {
    if (value == null) return;

    setState(() {
      _selectedTimeRange = value;
      if (value != 'Custom') {
        _setDefaultDates();
      }
    });
  }

  Map<String, dynamic> _calculateSummary(List<UsageEntry> entries) {
    print('📊 Calculating summary for ${entries.length} entries');

    // Debug: Print all entries
    for (final entry in entries) {
      print('🔍 Entry: ${entry.dateUsed} - ₹${entry.expense} - ${entry.quantityUsed}kg');
    }

    if (entries.isEmpty) {
      return {
        'totalExpense': 0.0,
        'totalTransactions': 0,
        'averageDailyExpense': 0.0,
        'maxDailyExpense': 0.0,
        'dailyExpenses': <String, double>{},
      };
    }

    // Sort entries by date
    entries.sort((a, b) => a.dateUsed.compareTo(b.dateUsed));

    final totalExpense = entries.fold<double>(0, (sum, entry) => sum + entry.expense);
    final totalTransactions = entries.length;

    print('💰 Total expense: $totalExpense');
    print('📋 Total transactions: $totalTransactions');

    // Group by date for daily calculations - use consistent date format
    final Map<String, double> dailyExpenses = {};
    final Map<DateTime, double> dailyExpenseByDate = {};

    for (final entry in entries) {
      // Normalize the date to remove time component for grouping
      final dateKey = DateTime(entry.dateUsed.year, entry.dateUsed.month, entry.dateUsed.day);
      final displayDateKey = DateFormat('dd MMM').format(entry.dateUsed);

      dailyExpenseByDate[dateKey] = (dailyExpenseByDate[dateKey] ?? 0) + entry.expense;
      dailyExpenses[displayDateKey] = (dailyExpenses[displayDateKey] ?? 0) + entry.expense;

      print('📅 Grouping: ${entry.dateUsed} -> $displayDateKey = ${dailyExpenses[displayDateKey]}');
    }

    print('📈 Daily expenses map: $dailyExpenses');

    // Calculate average and max daily expense
    final dailyTotals = dailyExpenseByDate.values.toList();

    final averageDailyExpense = dailyTotals.isEmpty ? 0 :
    dailyTotals.reduce((a, b) => a + b) / dailyTotals.length;
    final maxDailyExpense = dailyTotals.isEmpty ? 0 :
    dailyTotals.reduce((a, b) => a > b ? a : b);

    print('📊 Average daily: $averageDailyExpense, Max daily: $maxDailyExpense');

    return {
      'totalExpense': totalExpense,
      'totalTransactions': totalTransactions,
      'averageDailyExpense': averageDailyExpense,
      'maxDailyExpense': maxDailyExpense,
      'dailyExpenses': dailyExpenses,
      'entries': entries, // Pass original entries for transaction list
    };
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');
    final totalExpense = summary['totalExpense'] as double;
    final totalTransactions = summary['totalTransactions'] as int;
    final averageDailyExpense = summary['averageDailyExpense'] as double;
    final maxDailyExpense = summary['maxDailyExpense'] as double;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      padding: const EdgeInsets.all(8),
      children: [
        _buildSummaryCard(
          'Total Expense',
          currencyFormat.format(totalExpense),
          Icons.currency_rupee,
          Colors.green,
        ),
        _buildSummaryCard(
          'Transactions',
          totalTransactions.toString(),
          Icons.receipt,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Avg Daily',
          currencyFormat.format(averageDailyExpense),
          Icons.trending_up,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Max Daily',
          currencyFormat.format(maxDailyExpense),
          Icons.leaderboard,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<UsageEntry> entries) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Recent Transactions (${entries.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...entries.map((entry) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.inventory_2,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              'Used ${entry.quantityUsed.toStringAsFixed(2)} kg',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(dateFormat.format(entry.dateUsed)),
            trailing: Text(
              currencyFormat.format(entry.expense),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
            ),
          ),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Summary')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to view expenses',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final dateRangeUsage = ref.watch(
      dateRangeUsageProvider(DateRange(_startDate, _endDate)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dateRangeUsageProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedTimeRange,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _timeRanges.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: _onTimeRangeSelected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Selected Range'),
                    subtitle: Text(
                      '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: _selectDateRange,
                      tooltip: 'Select custom date range',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: dateRangeUsage.when(
              data: (entries) {
                print('✅ UI Building with ${entries.length} entries');

                final summary = _calculateSummary(entries);
                final displayEntries = summary['entries'] as List<UsageEntry>;

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses in this period',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add usage entries to see your expense summary',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dateRangeUsageProvider);
                  },
                  child: ListView(
                    children: [
                      // Summary Cards
                      _buildSummaryCards(summary),

                      // Chart Section
                      // Chart Section
                      if ((summary['dailyExpenses'] as Map<String, double>).isNotEmpty)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bar_chart),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Daily Expenses Trend',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: ExpenseChart(
                                    dailyExpenses: summary['dailyExpenses'] as Map<String, double>,
                                  ),
                                ),
                                // Add debug info
                                if (kDebugMode)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Debug: ${summary['dailyExpenses'].toString()}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // Transactions List
                      _buildTransactionList(displayEntries),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading expense summary...'),
                  ],
                ),
              ),
              error: (error, stack) {
                print('❌ Error loading expense summary: $error');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load expenses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(dateRangeUsageProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}