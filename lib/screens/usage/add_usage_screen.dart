import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../models/usage_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/usage_provider.dart';

class AddUsageScreen extends ConsumerStatefulWidget {
  const AddUsageScreen({super.key});

  @override
  ConsumerState<AddUsageScreen> createState() => _AddUsageScreenState();
}

class _AddUsageScreenState extends ConsumerState<AddUsageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  FoodItem? _selectedItem;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _overridePrice = false;
  List<FoodItem> _availableItems = [];
  Map<String, double> _remainingStocks = {};

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  Future<void> _loadRemainingStocks(List<FoodItem> items) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final stocks = <String, double>{};
    for (final item in items) {
      final remaining = await _getRemainingQuantityForMonth(item.id);
      stocks[item.id] = remaining;
    }

    if (mounted) {
      setState(() {
        _remainingStocks = stocks;
      });
    }
  }

  List<FoodItem> _filterAndSortItems(List<FoodItem> allItems) {
    // Filter: only items with same name and available stock, excluding closed months
    final itemsByName = <String, List<FoodItem>>{};

    for (final item in allItems) {
      if (!item.isMonthClosed && (_remainingStocks[item.id] ?? 0) > 0) {
        if (!itemsByName.containsKey(item.name)) {
          itemsByName[item.name] = [];
        }
        itemsByName[item.name]!.add(item);
      }
    }

    // Sort each name group by purchase date (oldest first)
    final sortedItems = <FoodItem>[];
    for (final items in itemsByName.values) {
      items.sort((a, b) => a.datePurchased.compareTo(b.datePurchased));
      sortedItems.addAll(items);
    }

    return sortedItems;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onItemSelected(FoodItem? item) {
    setState(() {
      _selectedItem = item;
      if (item != null && !_overridePrice) {
        _priceController.text = item.unitPrice.toStringAsFixed(2);
      }
    });
  }

  void _onOverridePriceChanged(bool? value) {
    setState(() {
      _overridePrice = value ?? false;
      if (!_overridePrice && _selectedItem != null) {
        _priceController.text = _selectedItem!.unitPrice.toStringAsFixed(2);
      }
    });
  }

  double _calculateExpense() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    return quantity * price;
  }

  Future<double> _getRemainingQuantityForMonth(String itemId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return 0;

    final itemsAsync = await ref.read(itemsProvider.future);
    final item = itemsAsync.firstWhere((i) => i.id == itemId);

    final usageAsync = await ref.read(usageProvider.future);
    final monthlyUsage = usageAsync
        .where((usage) =>
    usage.itemId == itemId &&
        _isSameMonth(usage.dateUsed, item.datePurchased))
        .toList();

    final totalUsed = monthlyUsage.fold<double>(
      0.0,
          (sum, usage) => sum + usage.quantityUsed,
    );

    final remaining = item.quantityPurchased - totalUsed;
    return remaining;
  }

  Future<void> _saveUsage() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final quantityUsed = double.parse(_quantityController.text);
      final unitPrice = double.parse(_priceController.text);
      final expense = quantityUsed * unitPrice;

      final remaining = await _getRemainingQuantityForMonth(_selectedItem!.id);

      if (quantityUsed > remaining) {
        if (mounted) {
          final monthFormat = DateFormat('MMMM yyyy');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient quantity in ${monthFormat.format(_selectedItem!.datePurchased)} stock.\n'
                    'Available: ${remaining.toStringAsFixed(2)} kg\n'
                    'Requested: ${quantityUsed.toStringAsFixed(2)} kg',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final usage = UsageEntry(
        id: '',
        itemId: _selectedItem!.id,
        quantityUsed: quantityUsed,
        dateUsed: _selectedDate,
        expense: expense,
      );

      await ref.read(firestoreServiceProvider).addUsage(user.uid, usage);

      if (mounted) {
        final monthFormat = DateFormat('MMMM yyyy');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usage recorded from ${monthFormat.format(_selectedItem!.datePurchased)} stock:\n'
                  '${quantityUsed.toStringAsFixed(2)} kg @ ₹${unitPrice.toStringAsFixed(2)}/kg\n'
                  'Remaining: ${(remaining - quantityUsed).toStringAsFixed(2)} kg',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
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
    final itemsAsync = ref.watch(itemsProvider);
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('FIFO Stock Usage'),
                  content: const Text(
                    'First In, First Out (FIFO) Method:\n\n'
                        '• Always use oldest stock first\n'
                        '• Items are sorted by purchase date\n'
                        '• Dropdown shows all available stocks with dates\n'
                        '• Oldest stock appears first for each item\n'
                        '• Only items with remaining stock are shown\n\n'
                        'Example:\n'
                        'If you have Rice from Oct and Nov, use October stock first before moving to November stock.\n\n'
                        'Price Override: By default, uses the purchase price. '
                        'Enable override if current market price differs.',
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // FIFO Notice
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FIFO Stock Management',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Always select the oldest stock first (First In, First Out)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Item Selection
            itemsAsync.when(
              data: (allItems) {
                if (_remainingStocks.isEmpty) {
                  _loadRemainingStocks(allItems);
                }

                final availableItems = _filterAndSortItems(allItems);
                _availableItems = availableItems;

                if (availableItems.isEmpty) {
                  return Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: Colors.orange),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'No items with available stock',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'All items are either fully consumed or from closed months.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<FoodItem>(
                      value: _selectedItem,
                      decoration: InputDecoration(
                        labelText: 'Select Item & Stock',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.inventory),
                        helperText: 'Select oldest stock first (FIFO)',
                        helperMaxLines: 2,
                      ),
                      isExpanded: true,
                      items: availableItems.map((item) {
                        final remaining = _remainingStocks[item.id] ?? 0;
                        final isOldest = _isOldestStock(item, availableItems);

                        return DropdownMenuItem(
                          value: item,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (isOldest)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'USE FIRST',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 11, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Purchased: ${dateFormat.format(item.datePurchased)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.event,
                                        size: 11, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      monthFormat.format(item.datePurchased),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '₹${item.unitPrice.toStringAsFixed(2)}/kg',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Available: ${remaining.toStringAsFixed(2)} kg',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: remaining > 0
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.isCarriedForward) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.forward,
                                          size: 10, color: Colors.blue[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Carried forward from previous month',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _onItemSelected,
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an item';
                        }
                        return null;
                      },
                      menuMaxHeight: 400,
                    ),
                    const SizedBox(height: 8),
                    // FIFO Warning for non-oldest selection
                    if (_selectedItem != null &&
                        !_isOldestStock(_selectedItem!, availableItems))
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Consider using older stock first (FIFO principle)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),

            // Item Details Card
            if (_selectedItem != null)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Selected Stock Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Purchase Date',
                        dateFormat.format(_selectedItem!.datePurchased),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Stock Month',
                        monthFormat.format(_selectedItem!.datePurchased),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Purchase Price',
                        '₹${_selectedItem!.unitPrice.toStringAsFixed(2)}/kg',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Purchased Quantity',
                        '${_selectedItem!.quantityPurchased.toStringAsFixed(2)} kg',
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<double>(
                        future:
                        _getRemainingQuantityForMonth(_selectedItem!.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Available Stock'),
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                  CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            );
                          }
                          if (snapshot.hasError) {
                            return _buildInfoRow(
                              'Available Stock',
                              'Error loading',
                              color: Colors.red,
                            );
                          }
                          final remaining = snapshot.data ?? 0;
                          return Column(
                            children: [
                              _buildInfoRow(
                                'Available Stock',
                                '${remaining.toStringAsFixed(2)} kg',
                                color:
                                remaining > 0 ? Colors.green : Colors.red,
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: remaining /
                                      _selectedItem!.quantityPurchased,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    remaining >
                                        _selectedItem!.quantityPurchased *
                                            0.5
                                        ? Colors.green
                                        : remaining >
                                        _selectedItem!
                                            .quantityPurchased *
                                            0.2
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Quantity Input
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity Used',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
                suffixText: 'kg',
                helperText: 'Enter the amount to use from this stock',
                helperMaxLines: 2,
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                final quantity = double.tryParse(value);
                if (quantity == null) {
                  return 'Please enter a valid number';
                }
                if (quantity <= 0) {
                  return 'Quantity must be greater than 0';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Price Override Section
            Card(
              color: Colors.amber[50],
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Override Price'),
                    subtitle: const Text(
                      'Use different price for this usage',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _overridePrice,
                    onChanged: _onOverridePriceChanged,
                    secondary: Icon(
                      _overridePrice ? Icons.edit : Icons.lock,
                      color: Colors.amber[700],
                    ),
                  ),
                  if (_overridePrice)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Current Unit Price',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.currency_rupee),
                          suffixText: '/kg',
                          helperText: 'Enter today\'s market price',
                          filled: true,
                          fillColor: Colors.white,
                          helperMaxLines: 2,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (_overridePrice) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter price';
                            }
                            final price = double.tryParse(value);
                            if (price == null) {
                              return 'Please enter a valid number';
                            }
                            if (price <= 0) {
                              return 'Price must be greater than 0';
                            }
                          }
                          return null;
                        },
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Expense Preview
            if (_selectedItem != null &&
                _quantityController.text.isNotEmpty &&
                _priceController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Expense Calculation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantity:'),
                        Text(
                          '${_quantityController.text} kg',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Price per kg:'),
                        Text(
                          '₹${_priceController.text}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Expense:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green[900],
                          ),
                        ),
                        Text(
                          '₹${_calculateExpense().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'From ${monthFormat.format(_selectedItem!.datePurchased)} stock (${dateFormat.format(_selectedItem!.datePurchased)})',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Date Selection
            ListTile(
              title: const Text('Usage Date'),
              subtitle: Text(
                dateFormat.format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.calendar_today),
              trailing: const Icon(Icons.edit_calendar),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 24),

            // Save Button
            FilledButton.icon(
              onPressed:
              _isLoading || _availableItems.isEmpty ? null : _saveUsage,
              icon: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Saving...' : 'Save Usage Entry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOldestStock(FoodItem item, List<FoodItem> allItems) {
    // Check if this is the oldest stock for this item name
    final sameNameItems = allItems.where((i) => i.name == item.name).toList();
    if (sameNameItems.isEmpty) return false;

    sameNameItems.sort((a, b) => a.datePurchased.compareTo(b.datePurchased));
    return sameNameItems.first.id == item.id;
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
