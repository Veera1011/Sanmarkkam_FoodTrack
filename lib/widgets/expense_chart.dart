// widgets/expense_chart.dart
import 'package:flutter/material.dart';

class ExpenseChart extends StatelessWidget {
  final Map<String, double> dailyExpenses;

  const ExpenseChart({super.key, required this.dailyExpenses});

  @override
  Widget build(BuildContext context) {
    if (dailyExpenses.isEmpty) {
      return Center(
        child: Text(
          'No data available for chart',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final entries = dailyExpenses.entries.toList();
    // Sort by date for consistent display
    entries.sort((a, b) => a.key.compareTo(b.key));

    final maxValue = dailyExpenses.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final barHeight = maxValue > 0 ? (entry.value / maxValue) : 0.0;

          return Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Value label
                Text(
                  '₹${entry.value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // Bar
                Expanded(
                  child: Container(
                    width: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: FractionallySizedBox(
                      heightFactor: barHeight.toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.blue.shade700, Colors.blue.shade400],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Date label
                Text(
                  entry.key,
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}