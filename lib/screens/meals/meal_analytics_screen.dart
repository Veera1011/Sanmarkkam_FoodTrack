
// lib/screens/meals/meal_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/meal_service.dart';
import '../../providers/meal_service_provider.dart';
import '../../providers/usage_provider.dart';

enum MealAnalyticsPeriod { week, month, year, custom }

class MealAnalyticsScreen extends ConsumerStatefulWidget {
  const MealAnalyticsScreen({super.key});

  @override
  ConsumerState<MealAnalyticsScreen> createState() => _MealAnalyticsScreenState();
}

class _MealAnalyticsScreenState extends ConsumerState<MealAnalyticsScreen> {
  MealAnalyticsPeriod _selectedPeriod = MealAnalyticsPeriod.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  DateRange _getDateRange() {
    final now = _selectedDate;

    switch (_selectedPeriod) {
      case MealAnalyticsPeriod.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0);
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return DateRange(start, end);

      case MealAnalyticsPeriod.month:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateRange(start, end);

      case MealAnalyticsPeriod.year:
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateRange(start, end);

      case MealAnalyticsPeriod.custom:
        final start = DateTime(_customStartDate.year, _customStartDate.month,
            _customStartDate.day, 0, 0, 0);
        final end = DateTime(_customEndDate.year, _customEndDate.month,
            _customEndDate.day, 23, 59, 59, 999);
        return DateRange(start, end);
    }
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
    final dateRange = _getDateRange();
    final mealsAsync = ref.watch(dateRangeMealServicesProvider(dateRange));

    return Column(
      children: [
        // Period Selector
        _buildPeriodSelector(),

        // Analytics Content
        Expanded(
          child: mealsAsync.when(
            data: (meals) => _buildAnalyticsContent(meals, dateRange),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Period',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('Week', MealAnalyticsPeriod.week),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Month', MealAnalyticsPeriod.month),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Year', MealAnalyticsPeriod.year),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Custom', MealAnalyticsPeriod.custom, onTap: _selectCustomRange),
                ],
              ),
            ),
            if (_selectedPeriod == MealAnalyticsPeriod.custom) ...[
              const SizedBox(height: 8),
              Text(
                '${DateFormat('dd MMM yyyy').format(_customStartDate)} - ${DateFormat('dd MMM yyyy').format(_customEndDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, MealAnalyticsPeriod period, {VoidCallback? onTap}) {
    final isSelected = _selectedPeriod == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (onTap != null) {
          onTap();
        }
        setState(() => _selectedPeriod = period);
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildAnalyticsContent(List<MealService> meals, DateRange dateRange) {
    if (meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No meal data for this period', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    // Calculate statistics
    final totalPeople = meals.fold<int>(0, (sum, meal) => sum + meal.numberOfPeople);
    final totalMeals = meals.length;
    final avgPeoplePerMeal = totalMeals > 0 ? (totalPeople / totalMeals).toStringAsFixed(1) : '0';

    // Group by meal type
    final breakfastCount = meals.where((m) => m.mealType == MealType.breakfast).length;
    final lunchCount = meals.where((m) => m.mealType == MealType.lunch).length;
    final dinnerCount = meals.where((m) => m.mealType == MealType.dinner).length;

    final breakfastPeople = meals
        .where((m) => m.mealType == MealType.breakfast)
        .fold<int>(0, (sum, m) => sum + m.numberOfPeople);
    final lunchPeople = meals
        .where((m) => m.mealType == MealType.lunch)
        .fold<int>(0, (sum, m) => sum + m.numberOfPeople);
    final dinnerPeople = meals
        .where((m) => m.mealType == MealType.dinner)
        .fold<int>(0, (sum, m) => sum + m.numberOfPeople);

    // Group by date for daily stats
    final Map<String, int> dailyPeople = {};
    for (final meal in meals) {
      final dateKey = DateFormat('yyyy-MM-dd').format(meal.date);
      dailyPeople[dateKey] = (dailyPeople[dateKey] ?? 0) + meal.numberOfPeople;
    }

    final maxDailyPeople = dailyPeople.values.isEmpty ? 0 : dailyPeople.values.reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dateRangeMealServicesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildStatCard(
                'Total People',
                totalPeople.toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                'Total Meals',
                totalMeals.toString(),
                Icons.restaurant,
                Colors.green,
              ),
              _buildStatCard(
                'Avg per Meal',
                avgPeoplePerMeal,
                Icons.trending_up,
                Colors.orange,
              ),
              _buildStatCard(
                'Max Daily',
                maxDailyPeople.toString(),
                Icons.leaderboard,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Meal Type Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pie_chart, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        'Meal Type Distribution',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMealTypeBar('🌅 Breakfast', breakfastCount, breakfastPeople, Colors.orange, totalMeals),
                  const SizedBox(height: 12),
                  _buildMealTypeBar('☀️ Lunch', lunchCount, lunchPeople, Colors.green, totalMeals),
                  const SizedBox(height: 12),
                  _buildMealTypeBar('🌙 Dinner', dinnerCount, dinnerPeople, Colors.indigo, totalMeals),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Daily Trend
          Card(
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
                        'Daily People Served',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildDailyChart(dailyPeople, maxDailyPeople),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Meals List
          Card(
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
                        'Recent Services',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...meals.take(10).map((meal) {
                    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Text(
                            meal.getMealTypeEmoji(),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.getMealTypeLabel(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  dateFormat.format(meal.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 14, color: Colors.blue[700]),
                                const SizedBox(width: 4),
                                Text(
                                  meal.numberOfPeople.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeBar(String label, int count, int people, Color color, int total) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '$count meals • $people people',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(Map<String, int> dailyPeople, int maxValue) {
    if (dailyPeople.isEmpty) {
      return Center(
        child: Text('No data', style: TextStyle(color: Colors.grey[600])),
      );
    }

    final sortedEntries = dailyPeople.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final barHeight = maxValue > 0 ? (entry.value / maxValue) : 0.0;
        final date = DateTime.parse(entry.key);

        return Container(
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                entry.value.toString(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Container(
                  width: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: FractionallySizedBox(
                    heightFactor: barHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd\nMMM').format(date),
                style: const TextStyle(fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}