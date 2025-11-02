// lib/screens/meals/add_meal_service_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/meal_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';

class AddMealServiceScreen extends ConsumerStatefulWidget {
  final MealService? mealService;

  const AddMealServiceScreen({super.key, this.mealService});

  @override
  ConsumerState<AddMealServiceScreen> createState() =>
      _AddMealServiceScreenState();
}

class _AddMealServiceScreenState extends ConsumerState<AddMealServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _peopleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  MealType _selectedMealType = MealType.lunch;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mealService != null) {
      _selectedDate = widget.mealService!.date;
      _selectedTime = TimeOfDay.fromDateTime(widget.mealService!.date);
      _selectedMealType = widget.mealService!.mealType;
      _peopleController.text = widget.mealService!.numberOfPeople.toString();
      _notesController.text = widget.mealService!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _peopleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveMealService() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (widget.mealService == null) {
        // Check if meal already exists
        final existing = await ref
            .read(firestoreServiceProvider)
            .getMealServiceByDateAndType(user.uid, dateTime, _selectedMealType);

        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${_selectedMealType.toString().split('.').last} already recorded for ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Create new
        final mealService = MealService(
          id: '',
          date: dateTime,
          mealType: _selectedMealType,
          numberOfPeople: int.parse(_peopleController.text),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdAt: DateTime.now(),
        );

        await ref
            .read(firestoreServiceProvider)
            .addMealService(user.uid, mealService);
      } else {
        // Update existing
        final updated = widget.mealService!.copyWith(
          date: dateTime,
          mealType: _selectedMealType,
          numberOfPeople: int.parse(_peopleController.text),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        await ref
            .read(firestoreServiceProvider)
            .updateMealService(user.uid, updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mealService == null
                ? 'Meal service recorded successfully'
                : 'Meal service updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        print(e);
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
    final dateFormat = DateFormat('dd MMM yyyy');
    final isEdit = widget.mealService != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Meal Service' : 'Add Meal Service'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Record the number of people served for each meal',
                        style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Meal Type Selection
            Text(
              'Meal Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<MealType>(
              segments: const [
                ButtonSegment(
                  value: MealType.breakfast,
                  label: Text('Breakfast'),
                  icon: Icon(Icons.wb_sunny),
                ),
                ButtonSegment(
                  value: MealType.lunch,
                  label: Text('Lunch'),
                  icon: Icon(Icons.wb_sunny_outlined),
                ),
                ButtonSegment(
                  value: MealType.dinner,
                  label: Text('Dinner'),
                  icon: Icon(Icons.nightlight),
                ),
              ],
              selected: {_selectedMealType},
              onSelectionChanged: (Set<MealType> selected) {
                setState(() => _selectedMealType = selected.first);
              },
            ),
            const SizedBox(height: 24),

            // Date and Time Selection
            Text(
              'Date & Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Date'),
                    subtitle: Text(
                      dateFormat.format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListTile(
                    title: const Text('Time'),
                    subtitle: Text(
                      _selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    leading: const Icon(Icons.access_time),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Number of People
            Text(
              'Number of People Served',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _peopleController,
              decoration: const InputDecoration(
                labelText: 'Number of People',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                helperText: 'Enter the total number of people served',
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter number of people';
                }
                final number = int.tryParse(value);
                if (number == null) {
                  return 'Please enter a valid number';
                }
                if (number <= 0) {
                  return 'Number must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Notes (Optional)
            Text(
              'Notes (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                hintText: 'Any additional notes or details',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveMealService,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(_isLoading
                  ? 'Saving...'
                  : isEdit
                  ? 'Update Meal Service'
                  : 'Save Meal Service'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
