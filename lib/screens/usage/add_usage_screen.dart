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
  FoodItem? _selectedItem;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
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
      final expense = quantityUsed * _selectedItem!.unitPrice;

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
          const SnackBar(content: Text('Usage added successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
      appBar: AppBar(title: const Text('Add Usage')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No items available. Please add items first.'),
                    ),
                  );
                }
                return DropdownButtonFormField<FoodItem>(
                  value: _selectedItem,
                  decoration: const InputDecoration(
                    labelText: 'Select Item',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory),
                  ),
                  items: items.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item.name),
                    );
                  }).toList(),
                  onChanged: (item) {
                    setState(() => _selectedItem = item);
                  },
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
            if (_selectedItem != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Unit Price: ₹${_selectedItem!.unitPrice.toStringAsFixed(2)}'),
                      Consumer(
                        builder: (context, ref, child) {
                          final remainingAsync = ref.watch(
                            itemRemainingQuantityProvider(_selectedItem!.id),
                          );
                          return remainingAsync.when(
                            data: (remaining) => Text(
                              'Remaining: ${remaining.toStringAsFixed(2)} kg',
                              style: TextStyle(
                                color: remaining > 0 ? Colors.green : Colors.red,
                              ),
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
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity Used (kg/liters)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Quantity must be greater than 0';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
            ),
            if (_selectedItem != null && _quantityController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Estimated Expense: ₹${(double.tryParse(_quantityController.text) ?? 0 * _selectedItem!.unitPrice).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Usage Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              leading: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _saveUsage,
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save Usage'),
            ),
          ],
        ),
      ),
    );
  }
}