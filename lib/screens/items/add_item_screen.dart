import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  FoodItem? _matchingItem; // Item with same name, month, AND price
  bool _willCreateNewEntry = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
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
        if (_nameController.text.isNotEmpty &&
            _priceController.text.isNotEmpty) {
          _checkForMatching();
        }
      });
    }
  }

  Future<void> _checkForMatching() async {
    if (_nameController.text.trim().isEmpty || _priceController.text.isEmpty) {
      setState(() {
        _matchingItem = null;
        _willCreateNewEntry = true;
      });
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final price = double.tryParse(_priceController.text);
    if (price == null) return;

    try {
      final matching =
      await ref.read(firestoreServiceProvider).findMatchingItemForPurchase(
        user.uid,
        _nameController.text.trim(),
        _selectedDate,
        price,
      );

      setState(() {
        _matchingItem = matching;
        _willCreateNewEntry = matching == null;
      });

      if (matching != null) {
        _showMatchingItemDialog(matching);
      }
    } catch (e) {
      print('Error checking for matching item: $e');
    }
  }

  void _showMatchingItemDialog(FoodItem item) {
    final monthFormat = DateFormat('MMMM yyyy');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text('Exact Match Found!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found "${item.name}" in ${monthFormat.format(item.datePurchased)} with the same price',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Current Stock',
                      '${item.quantityPurchased.toStringAsFixed(2)} kg'),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                      'Price', '₹${item.unitPrice.toStringAsFixed(2)}/kg'),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                      'Month', monthFormat.format(item.datePurchased)),
                  if (item.isCarriedForward) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.forward, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Carried forward from previous month',
                          style:
                          TextStyle(fontSize: 11, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock will be added to this entry (same month, same price)',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nameController.clear();
              _priceController.clear();
              setState(() {
                _matchingItem = null;
                _willCreateNewEntry = true;
              });
            },
            child: const Text('Change Details'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to This Stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final quantity = double.parse(_quantityController.text);
      final price = double.parse(_priceController.text);

      if (_matchingItem != null) {
        // Add to existing item (same name, month, and price)
        final newTotalQuantity = _matchingItem!.quantityPurchased + quantity;

        final updatedItem = _matchingItem!.copyWith(
          quantityPurchased: newTotalQuantity,
        );

        await ref
            .read(firestoreServiceProvider)
            .updateItem(user.uid, updatedItem);

        if (mounted) {
          final monthFormat = DateFormat('MMMM yyyy');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${quantity.toStringAsFixed(2)} kg to $name\n'
                    'Total stock: ${newTotalQuantity.toStringAsFixed(2)} kg @ ₹${price.toStringAsFixed(2)}/kg\n'
                    'Month: ${monthFormat.format(_selectedDate)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Create new item (different month, different price, or first entry)
        final item = FoodItem(
          id: '',
          name: name,
          quantityPurchased: quantity,
          unitPrice: price,
          datePurchased: _selectedDate,
          isCarriedForward: false,
          isMonthClosed: false,
        );

        await ref.read(firestoreServiceProvider).addItem(user.uid, item);

        if (mounted) {
          final monthFormat = DateFormat('MMMM yyyy');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'New entry created: $name\n'
                    '${quantity.toStringAsFixed(2)} kg @ ₹${price.toStringAsFixed(2)}/kg\n'
                    'Month: ${monthFormat.format(_selectedDate)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
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

    return Scaffold(
      appBar: AppBar(
        title:
        Text(_matchingItem != null ? 'Add More Stock' : 'Add New Purchase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Smart Inventory System'),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Price-Based Tracking:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Same item + Same month + Same price = Combined stock\n'
                              '• Same item + Same month + Different price = Separate entry\n'
                              '• Different month = Always separate entry',
                          style: TextStyle(fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Example 1:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Oct 5: Rice 10kg @₹45/kg\n'
                              'Oct 15: Rice 5kg @₹45/kg\n'
                              '→ Combined: 15kg @₹45/kg',
                          style: TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Example 2:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Oct 5: Rice 10kg @₹45/kg\n'
                              'Oct 15: Rice 5kg @₹50/kg\n'
                              '→ Two entries (price differs)',
                          style: TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Month Closing:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'When you close a month, remaining stock automatically carries forward to next month.',
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month Indicator
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.purple[700]),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Purchase Month',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          monthFormat.format(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Matching Item Info
            if (_matchingItem != null)
              Card(
                color: Colors.green[50],
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Adding to Existing Stock',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildInfoRowWidget('Item', _matchingItem!.name),
                      const SizedBox(height: 6),
                      _buildInfoRowWidget(
                        'Current Stock',
                        '${_matchingItem!.quantityPurchased.toStringAsFixed(2)} kg',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRowWidget(
                        'Price',
                        '₹${_matchingItem!.unitPrice.toStringAsFixed(2)}/kg',
                      ),
                    ],
                  ),
                ),
              ),

            // Item Name Input
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.food_bank),
                hintText: 'e.g., Rice, Wheat, Oil',
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                // Trigger check when both name and price are filled
                if (_priceController.text.isNotEmpty) {
                  _checkForMatching();
                }
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price Input (moved before quantity to check matching early)
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Unit Price',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
                suffixText: '/kg',
                helperText: 'Price affects whether stock is combined',
                helperMaxLines: 2,
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setState(() {});
                // Check for matching when price changes
                if (_nameController.text.isNotEmpty) {
                  _checkForMatching();
                }
              },
              validator: (value) {
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
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quantity Input
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: _matchingItem != null
                    ? 'Quantity to Add'
                    : 'Quantity Purchased',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.scale),
                suffixText: 'kg',
                helperText: _matchingItem != null
                    ? 'Will be added to existing stock'
                    : 'Total quantity purchased',
                helperMaxLines: 2,
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => setState(() {}),
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
            ),
            const SizedBox(height: 16),

            // Total Cost Calculator
            if (_quantityController.text.isNotEmpty &&
                _priceController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[50]!, Colors.purple[100]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Purchase Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
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
                          'Total Cost:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.purple[900],
                          ),
                        ),
                        Text(
                          '₹${_calculateTotalCost().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                    if (_matchingItem != null) ...[
                      const Divider(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Current Stock:'),
                                Text(
                                  '${_matchingItem!.quantityPurchased.toStringAsFixed(2)} kg',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Adding:'),
                                Text(
                                  '+ ${_quantityController.text} kg',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'New Total:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                                Text(
                                  '${(_matchingItem!.quantityPurchased + (double.tryParse(_quantityController.text) ?? 0)).toStringAsFixed(2)} kg',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Date Selection
            ListTile(
              title: const Text('Purchase Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} (${monthFormat.format(_selectedDate)})',
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
              onPressed: _isLoading ? null : _saveItem,
              icon: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(_matchingItem != null
                  ? Icons.add_shopping_cart
                  : Icons.save),
              label: Text(
                _isLoading
                    ? 'Saving...'
                    : _matchingItem != null
                    ? 'Add to Existing Stock'
                    : 'Create New Entry',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalCost() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    return quantity * price;
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInfoRowWidget(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
