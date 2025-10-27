import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  FoodItem? _existingItem;
  bool _isEditMode = false;

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
      setState(() => _selectedDate = picked);
    }
  }

  double _calculateTotalCost() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    return quantity * price;
  }

  void _onNameChanged(String name, List<FoodItem> items) {
    if (name.trim().isEmpty) {
      setState(() {
        _existingItem = null;
        _isEditMode = false;
      });
      return;
    }

    // Check if item with this name already exists (case-insensitive)
    final existing = items.where((item) =>
    item.name.toLowerCase() == name.trim().toLowerCase()
    ).toList();

    if (existing.isNotEmpty) {
      setState(() {
        _existingItem = existing.first;
        _isEditMode = true;
      });

      // Show dialog to user
      if (!_isLoading) {
        _showExistingItemDialog(existing.first);
      }
    } else {
      setState(() {
        _existingItem = null;
        _isEditMode = false;
      });
    }
  }

  void _showExistingItemDialog(FoodItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Item Already Exists'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${item.name}" is already in your inventory.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('You can:'),
            const SizedBox(height: 8),
            _buildOptionTile(
              Icons.add_circle_outline,
              'Add More Stock',
              'Add new purchase quantity at today\'s price',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              Icons.edit,
              'Create Different Item',
              'Use a different name (e.g., "Rice - Basmati")',
              Colors.orange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nameController.clear();
              setState(() {
                _existingItem = null;
                _isEditMode = false;
              });
            },
            child: const Text('Change Name'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add More Stock'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
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

      if (_isEditMode && _existingItem != null) {
        // Add to existing item's stock
        final newTotalQuantity = _existingItem!.quantityPurchased + quantity;

        // Update the existing item with new quantity and latest price
        final updatedItem = FoodItem(
          id: _existingItem!.id,
          name: _existingItem!.name,
          quantityPurchased: newTotalQuantity,
          unitPrice: price, // Use latest purchase price
          datePurchased: _selectedDate,
        );

        await ref.read(firestoreServiceProvider).updateItem(user.uid, updatedItem);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${quantity.toStringAsFixed(2)} kg to ${name}\n'
                    'Total stock: ${newTotalQuantity.toStringAsFixed(2)} kg @ ₹${price.toStringAsFixed(2)}/kg',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Create new item
        final item = FoodItem(
          id: '',
          name: name,
          quantityPurchased: quantity,
          unitPrice: price,
          datePurchased: _selectedDate,
        );

        await ref.read(firestoreServiceProvider).addItem(user.uid, item);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'New item added: $name\n'
                    '${quantity.toStringAsFixed(2)} kg @ ₹${price.toStringAsFixed(2)}/kg',
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
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Add More Stock' : 'Add New Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Smart Inventory'),
                  content: const Text(
                    'This system prevents duplicate items:\n\n'
                        '• If an item exists, you can add more stock\n'
                        '• Each purchase can have different prices\n'
                        '• The system uses the latest purchase price\n'
                        '• Usage entries track their own prices\n\n'
                        'Example: Add Rice at ₹45/kg today, add more '
                        'Rice at ₹48/kg next week - no duplicates!',
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
      body: itemsAsync.when(
        data: (items) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Existing Item Warning
              if (_isEditMode && _existingItem != null)
                Card(
                  color: Colors.blue[50],
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Existing Item Found',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _buildInfoRow('Item Name', _existingItem!.name),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Current Stock',
                          '${_existingItem!.quantityPurchased.toStringAsFixed(2)} kg',
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Last Price',
                          '₹${_existingItem!.unitPrice.toStringAsFixed(2)}/kg',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle, color: Colors.green[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You\'re adding more stock to this item',
                                  style: TextStyle(
                                    color: Colors.green[700],
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
                  ),
                ),

              // Item Name Input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.food_bank),
                  hintText: 'e.g., Rice, Wheat, Oil',
                  suffixIcon: _isEditMode
                      ? Icon(Icons.check_circle, color: Colors.green[700])
                      : null,
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (value) => _onNameChanged(value, items),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quantity Input
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: _isEditMode ? 'Quantity to Add' : 'Quantity Purchased',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.scale),
                  suffixText: 'kg',
                  helperText: _isEditMode
                      ? 'Enter how much you\'re adding'
                      : 'Enter total quantity purchased',
                  helperMaxLines: 2,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

              // Price Input
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Unit Price',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  suffixText: '/kg',
                  helperText: 'Enter price per kilogram',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => setState(() {}),
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
                            'Purchase Calculation',
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
                      if (_isEditMode && _existingItem != null) ...[
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
                                    '${_existingItem!.quantityPurchased.toStringAsFixed(2)} kg',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                                    '${(_existingItem!.quantityPurchased + (double.tryParse(_quantityController.text) ?? 0)).toStringAsFixed(2)} kg',
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
                    : Icon(_isEditMode ? Icons.add_shopping_cart : Icons.save),
                label: Text(
                  _isLoading
                      ? 'Saving...'
                      : _isEditMode
                      ? 'Add to Stock'
                      : 'Save Item',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
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
}