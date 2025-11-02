// lib/screens/meals/meal_services_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/meal_service.dart';
import '../../providers/meal_service_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import './add_meal_service_screen.dart';
import './meal_analytics_screen.dart';

class MealServicesScreen extends ConsumerStatefulWidget {
  const MealServicesScreen({super.key});

  @override
  ConsumerState<MealServicesScreen> createState() => _MealServicesScreenState();
}

class _MealServicesScreenState extends ConsumerState<MealServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Services'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'Today\'s Meals'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TodaysMealsTab(),
          MealAnalyticsScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const AddMealServiceScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      )
          : null,
    );
  }
}

class _TodaysMealsTab extends ConsumerWidget {
  const _TodaysMealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysMealsAsync = ref.watch(todaysMealServicesProvider);
    final totalPeople = ref.watch(todaysTotalPeopleProvider);

    return Column(
      children: [
        // Summary Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange[100]!,
                Colors.orange[50]!,
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Service',
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMMM yyyy').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 40,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      'Total People',
                      totalPeople.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    todaysMealsAsync.when(
                      data: (meals) => _buildStatItem(
                        context,
                        'Meals Served',
                        meals.length.toString(),
                        Icons.fastfood,
                        Colors.green,
                      ),
                      loading: () => _buildStatItem(
                        context,
                        'Meals Served',
                        '...',
                        Icons.fastfood,
                        Colors.green,
                      ),
                      error: (e, s) => _buildStatItem(
                        context,
                        'Meals Served',
                        '0',
                        Icons.fastfood,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Meals List
        Expanded(
          child: todaysMealsAsync.when(
            data: (meals) {
              if (meals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No meals recorded today',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + button to add a meal service',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              // Group meals by type
              final breakfast =
              meals.where((m) => m.mealType == MealType.breakfast).toList();
              final lunch =
              meals.where((m) => m.mealType == MealType.lunch).toList();
              final dinner =
              meals.where((m) => m.mealType == MealType.dinner).toList();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (breakfast.isNotEmpty) ...[
                    _buildMealTypeSection(context, ref, 'Breakfast', breakfast,
                        MealType.breakfast),
                    const SizedBox(height: 16),
                  ],
                  if (lunch.isNotEmpty) ...[
                    _buildMealTypeSection(
                        context, ref, 'Lunch', lunch, MealType.lunch),
                    const SizedBox(height: 16),
                  ],
                  if (dinner.isNotEmpty) ...[
                    _buildMealTypeSection(
                        context, ref, 'Dinner', dinner, MealType.dinner),
                    const SizedBox(height: 16),
                  ],
                  // Show missing meals
                  if (breakfast.isEmpty || lunch.isEmpty || dinner.isEmpty) ...[
                    Card(
                      color: Colors.amber[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.amber[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Pending Meals',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (breakfast.isEmpty)
                              Text('🌅 Breakfast not recorded yet',
                                  style: TextStyle(color: Colors.amber[800])),
                            if (lunch.isEmpty)
                              Text('☀️ Lunch not recorded yet',
                                  style: TextStyle(color: Colors.amber[800])),
                            if (dinner.isEmpty)
                              Text('🌙 Dinner not recorded yet',
                                  style: TextStyle(color: Colors.amber[800])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
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
                    onPressed: () => ref.invalidate(todaysMealServicesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeSection(
      BuildContext context,
      WidgetRef ref,
      String title,
      List<MealService> meals,
      MealType mealType,
      ) {
    final meal = meals.first;
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getMealTypeColor(mealType).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  meal.getMealTypeEmoji(),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeFormat.format(meal.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getMealTypeColor(mealType),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        meal.numberOfPeople.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (meal.notes != null && meal.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meal.notes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddMealServiceScreen(
                          mealService: meal,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Meal Service'),
                        content: Text(
                            'Are you sure you want to delete this $title service?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      final user = ref.read(currentUserProvider);
                      if (user != null) {
                        await ref
                            .read(firestoreServiceProvider)
                            .deleteMealService(user.uid, meal.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$title service deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getMealTypeColor(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return Colors.orange;
      case MealType.lunch:
        return Colors.green;
      case MealType.dinner:
        return Colors.indigo;
    }
  }
}
