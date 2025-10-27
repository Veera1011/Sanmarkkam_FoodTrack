import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_item.dart';
import '../../models/usage_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';

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

  @override
  void dispose() {
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
      setState(() => _selectedDate = picked);
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

      // Check if enough quantity is available
      final remaining = await ref
          .read(firestoreServiceProvider)
          .getRemainingQuantity(user.uid, _selectedItem!.id);

      if (quantityUsed > remaining) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient quantity. Available: ${remaining.toStringAsFixed(2)} kg',
              ),
              backgroundColor: Colors.red,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usage added: ${quantityUsed.toStringAsFixed(2)} kg @ ₹${unitPrice.toStringAsFixed(2)}/kg',
            ),
            backgroundColor: Colors.green,
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
                  title: const Text('Price Information'),
                  content: const Text(
                    'By default, the purchase price is used. '
                        'Enable "Override Price" if the current market price '
                        'is different from when you purchased it.\n\n'
                        'Each usage entry will maintain its own price, '
                        'allowing accurate expense tracking even when '
                        'prices fluctuate.',
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
            // Item Selection
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Card(
                    color: Colors.orange[50],
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No items available. Please add items first.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return DropdownButtonFormField<FoodItem>(
                  value: _selectedItem,
                  decoration: const InputDecoration(
                    labelText: 'Select Item',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory),
                    helperText: 'Choose the food item you used',
                  ),
                  items: items.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.name),
                          Text(
                            'Purchase price: ₹${item.unitPrice.toStringAsFixed(2)}/kg',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
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
                            'Item Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Purchase Price',
                        '₹${_selectedItem!.unitPrice.toStringAsFixed(2)}/kg',
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final remainingAsync = ref.watch(
                            itemRemainingQuantityProvider(_selectedItem!.id),
                          );
                          return remainingAsync.when(
                            data: (remaining) => _buildInfoRow(
                              'Available Stock',
                              '${remaining.toStringAsFixed(2)} kg',
                              color: remaining > 0 ? Colors.green : Colors.red,
                            ),
                            loading: () => const Text('Loading...'),
                            error: (_, __) => const Text('Error loading quantity'),
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
                helperText: 'Enter the amount you used today',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Date Selection
            ListTile(
              title: const Text('Usage Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
              onPressed: _isLoading ? null : _saveUsage,
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