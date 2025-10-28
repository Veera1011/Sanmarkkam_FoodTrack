// screens/items/month_closing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';

class MonthClosingScreen extends ConsumerStatefulWidget {
  const MonthClosingScreen({super.key});

  @override
  ConsumerState<MonthClosingScreen> createState() => _MonthClosingScreenState();
}

class _MonthClosingScreenState extends ConsumerState<MonthClosingScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  Set<String> _selectedItems = {};

  Future<void> _selectMonth() async {
    await showDialog(
      context: context,
      builder: (context) => _MonthYearPicker(
        initialDate: _selectedMonth,
        onDateSelected: (date) {
          setState(() {
            _selectedMonth = date;
            _selectedItems.clear();
          });
        },
      ),
    );
  }

  Future<void> _closeSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to close')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Month Closing'),
        content: Text(
          'Are you sure you want to close ${_selectedItems.length} item(s) for ${DateFormat('MMMM yyyy').format(_selectedMonth)}?\n\n'
              'Remaining stock will be automatically carried forward to next month.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close Month'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      int successCount = 0;
      int carriedForward = 0;
      double totalCarriedQty = 0;

      for (final itemId in _selectedItems) {
        try {
          final newItemId =
          await ref.read(firestoreServiceProvider).closeMonthForItem(
            user.uid,
            itemId,
          );

          successCount++;

          if (newItemId != null) {
            carriedForward++;
            // Get the remaining quantity that was carried
            final remaining =
            await ref.read(firestoreServiceProvider).getRemainingQuantity(
              user.uid,
              itemId,
            );
            totalCarriedQty += remaining;
          }
        } catch (e) {
          print('Error closing item $itemId: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Month closed successfully!\n'
                  '✓ $successCount items closed\n'
                  '✓ $carriedForward items carried forward\n'
                  '✓ ${totalCarriedQty.toStringAsFixed(2)} kg carried to next month',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        setState(() {
          _selectedItems.clear();
        });

        // Refresh the items list
        ref.invalidate(itemsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy');
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Close Month')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Close Month'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Month Closing Guide'),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'What happens when you close a month?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. System calculates remaining stock\n'
                              '2. If stock remains:\n'
                              '   • Creates new entry in next month\n'
                              '   • Marks it as "carried forward"\n'
                              '   • Carries same price\n'
                              '3. Prevents further purchases/usage for that month\n'
                              '4. Maintains accurate monthly inventory',
                          style: TextStyle(fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Example:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'October:\n'
                              '• Purchased: 15 kg Rice @₹45/kg\n'
                              '• Used: 13 kg\n'
                              '• Remaining: 2 kg\n\n'
                              'After closing October:\n'
                              '• November automatically gets:\n'
                              '  2 kg Rice @₹45/kg (carried forward)\n'
                              '• October is locked (no more changes)',
                          style: TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Best Practice:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Close months at the end of each month to maintain accurate records and prevent confusion.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Select Month to Close'),
              subtitle: Text(
                monthFormat.format(_selectedMonth),
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_calendar),
                onPressed: _selectMonth,
              ),
              onTap: _selectMonth,
            ),
          ),

          // Items List
          Expanded(
            child: FutureBuilder<List<FoodItem>>(
              future: ref.read(firestoreServiceProvider).getItemsByMonth(
                user.uid,
                _selectedMonth,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final allItems = snapshot.data ?? [];
                final unclosedItems =
                allItems.where((item) => !item.isMonthClosed).toList();

                if (allItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No items found for ${monthFormat.format(_selectedMonth)}',
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a different month',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                if (unclosedItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            size: 80, color: Colors.green[400]),
                        const SizedBox(height: 16),
                        Text(
                          'All items are already closed for\n${monthFormat.format(_selectedMonth)}',
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${allItems.length} item(s) closed',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Summary Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Total Items',
                            allItems.length.toString(),
                            Icons.inventory,
                            Colors.blue,
                          ),
                          _buildSummaryItem(
                            'Open',
                            unclosedItems.length.toString(),
                            Icons.pending,
                            Colors.orange,
                          ),
                          _buildSummaryItem(
                            'Closed',
                            (allItems.length - unclosedItems.length).toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Select All
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value:
                            _selectedItems.length == unclosedItems.length &&
                                unclosedItems.isNotEmpty,
                            tristate: _selectedItems.isNotEmpty &&
                                _selectedItems.length < unclosedItems.length,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedItems = unclosedItems
                                      .map((item) => item.id)
                                      .toSet();
                                } else {
                                  _selectedItems.clear();
                                }
                              });
                            },
                          ),
                          Text(
                            'Select All (${_selectedItems.length}/${unclosedItems.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Items List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          return _buildItemCard(item, user.uid);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Close Button
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _closeSelectedItems,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.done_all),
                label: Text(
                  _isLoading
                      ? 'Closing...'
                      : 'Close ${_selectedItems.length} Item(s)',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(FoodItem item, String userId) {
    final isClosed = item.isMonthClosed;
    final isSelected = _selectedItems.contains(item.id);

    return FutureBuilder<double>(
      future: ref
          .read(firestoreServiceProvider)
          .getRemainingQuantity(userId, item.id),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isClosed ? Colors.grey[100] : null,
          child: CheckboxListTile(
            value: isClosed ? false : isSelected,
            enabled: !isClosed,
            onChanged: isClosed
                ? null
                : (value) {
              setState(() {
                if (value == true) {
                  _selectedItems.add(item.id);
                } else {
                  _selectedItems.remove(item.id);
                }
              });
            },
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isClosed ? Colors.grey : null,
                    ),
                  ),
                ),
                if (isClosed)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Closed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (item.isCarriedForward && !isClosed)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Carried',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Purchased: ${item.quantityPurchased.toStringAsFixed(2)} kg'),
                          Text(
                              'Price: ₹${item.unitPrice.toStringAsFixed(2)}/kg'),
                        ],
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Remaining',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                          Text(
                            '${remaining.toStringAsFixed(2)} kg',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: remaining > 0 ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (remaining > 0 && !isClosed) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Will carry ${remaining.toStringAsFixed(2)} kg to next month',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber[900],
                              fontWeight: FontWeight.w600,
                            ),
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
      },
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
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
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
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM').format(DateTime(2000, month)),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
