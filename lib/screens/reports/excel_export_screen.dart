// lib/screens/reports/excel_export_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/usage_provider.dart';
import '../../models/food_item.dart';
import '../../models/usage_entry.dart';
import '../../services/excel_export_service.dart';

enum ExportPeriod { day, month, year, custom }

enum ExportType { summary, detailed, inventory, usage, all }

class ExcelExportScreen extends ConsumerStatefulWidget {
  const ExcelExportScreen({super.key});

  @override
  ConsumerState<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends ConsumerState<ExcelExportScreen> {
  ExportPeriod _selectedPeriod = ExportPeriod.month;
  Set<ExportType> _selectedTypes = {ExportType.all};
  DateTime _selectedDate = DateTime.now();
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();
  bool _isExporting = false;

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

  Future<void> _selectMonth() async {
    await showDialog(
      context: context,
      builder: (context) => _MonthYearPicker(
        initialDate: _selectedDate,
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
        },
      ),
    );
  }

  Future<void> _selectYear() async {
    await showDialog(
      context: context,
      builder: (context) => _YearPicker(
        initialYear: _selectedDate.year,
        onYearSelected: (year) {
          setState(() => _selectedDate =
              DateTime(year, _selectedDate.month, _selectedDate.day));
        },
      ),
    );
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
      DateTimeRange(start: _customStartDate, end: _customEndDate),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  DateRange _getDateRange() {
    final now = _selectedDate;

    switch (_selectedPeriod) {
      case ExportPeriod.day:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateRange(start, end);

      case ExportPeriod.month:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateRange(start, end);

      case ExportPeriod.year:
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateRange(start, end);

      case ExportPeriod.custom:
        final start = DateTime(_customStartDate.year, _customStartDate.month,
            _customStartDate.day, 0, 0, 0);
        final end = DateTime(_customEndDate.year, _customEndDate.month,
            _customEndDate.day, 23, 59, 59, 999);
        return DateRange(start, end);
    }
  }

  Future<void> _exportToExcel() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showSnackBar('Please log in to export data', Colors.red);
      return;
    }

    if (_selectedTypes.isEmpty) {
      _showSnackBar('Please select at least one report type', Colors.orange);
      return;
    }

    // Request storage permission
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          _showSnackBar(
              'Storage permission is required to save files', Colors.red);
        }
        return;
      }
    }

    setState(() => _isExporting = true);

    try {
      final dateRange = _getDateRange();

      // Fetch data
      final itemsAsync = await ref.read(itemsProvider.future);
      final usageAsync =
      await ref.read(dateRangeUsageProvider(dateRange).future);

      // Filter items by date range
      final items = itemsAsync.where((item) {
        return item.datePurchased.isAfter(
            dateRange.start.subtract(const Duration(seconds: 1))) &&
            item.datePurchased
                .isBefore(dateRange.end.add(const Duration(seconds: 1)));
      }).toList();

      // Determine export types
      final types = _selectedTypes.contains(ExportType.all)
          ? {
        ExportType.summary,
        ExportType.detailed,
        ExportType.inventory,
        ExportType.usage
      }
          : _selectedTypes;

      // Generate Excel
      final excel = Excel.createExcel();
      final excelService = ExcelService();

      // Remove default sheet
      excel.delete('Sheet1');

      // Add sheets based on selected types
      if (types.contains(ExportType.summary)) {
        excelService.addSummarySheet(excel, items, usageAsync, dateRange);
      }

      if (types.contains(ExportType.detailed)) {
        excelService.addDetailedExpenseSheet(
            excel, items, usageAsync, dateRange);
      }

      if (types.contains(ExportType.inventory)) {
        excelService.addInventorySheet(excel, items, usageAsync, dateRange);
      }

      if (types.contains(ExportType.usage)) {
        excelService.addUsageHistorySheet(excel, usageAsync, items, dateRange);
      }

      // Generate filename
      final periodStr = _getPeriodString();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'FoodTrack_${periodStr}_$timestamp.xlsx';

      // Save file
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      final filePath = await excelService.saveToDownloads(fileBytes, filename);

      if (mounted) {
        _showSuccessDialog(filePath, filename);
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      if (mounted) {
        _showSnackBar('Error exporting data: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _getPeriodString() {
    switch (_selectedPeriod) {
      case ExportPeriod.day:
        return DateFormat('dd_MMM_yyyy').format(_selectedDate);
      case ExportPeriod.month:
        return DateFormat('MMM_yyyy').format(_selectedDate);
      case ExportPeriod.year:
        return DateFormat('yyyy').format(_selectedDate);
      case ExportPeriod.custom:
        return '${DateFormat('dd_MMM').format(_customStartDate)}_to_${DateFormat('dd_MMM_yyyy').format(_customEndDate)}';
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog(String filePath, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 32),
            const SizedBox(width: 12),
            const Expanded(child: Text('Export Successful!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your report has been exported successfully.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                //  border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Saved to Downloads',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filePath,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Open the file from your Downloads folder using Excel or Google Sheets.',
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMMM yyyy');
    final yearFormat = DateFormat('yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export to Excel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const _HelpDialog(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.blue[700], size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel Report Generator',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate comprehensive reports for your food inventory and expenses',
                          style:
                          TextStyle(fontSize: 13, color: Colors.blue[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Period Selection
          Text(
            '1. Select Time Period',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                RadioListTile<ExportPeriod>(
                  title: const Text('Day'),
                  subtitle: Text(dateFormat.format(_selectedDate)),
                  value: ExportPeriod.day,
                  groupValue: _selectedPeriod,
                  onChanged: (value) {
                    setState(() => _selectedPeriod = value!);
                  },
                  secondary: const Icon(Icons.today),
                ),
                if (_selectedPeriod == ExportPeriod.day)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ElevatedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Change Date'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                RadioListTile<ExportPeriod>(
                  title: const Text('Month'),
                  subtitle: Text(monthFormat.format(_selectedDate)),
                  value: ExportPeriod.month,
                  groupValue: _selectedPeriod,
                  onChanged: (value) {
                    setState(() => _selectedPeriod = value!);
                  },
                  secondary: const Icon(Icons.calendar_month),
                ),
                if (_selectedPeriod == ExportPeriod.month)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ElevatedButton.icon(
                      onPressed: _selectMonth,
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Change Month'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                RadioListTile<ExportPeriod>(
                  title: const Text('Year'),
                  subtitle: Text(yearFormat.format(_selectedDate)),
                  value: ExportPeriod.year,
                  groupValue: _selectedPeriod,
                  onChanged: (value) {
                    setState(() => _selectedPeriod = value!);
                  },
                  secondary: const Icon(Icons.calendar_today),
                ),
                if (_selectedPeriod == ExportPeriod.year)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ElevatedButton.icon(
                      onPressed: _selectYear,
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Change Year'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                RadioListTile<ExportPeriod>(
                  title: const Text('Custom Range'),
                  subtitle: Text(
                    '${dateFormat.format(_customStartDate)} - ${dateFormat.format(_customEndDate)}',
                  ),
                  value: ExportPeriod.custom,
                  groupValue: _selectedPeriod,
                  onChanged: (value) {
                    setState(() => _selectedPeriod = value!);
                  },
                  secondary: const Icon(Icons.date_range),
                ),
                if (_selectedPeriod == ExportPeriod.custom)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ElevatedButton.icon(
                      onPressed: _selectCustomRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('Change Date Range'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Report Type Selection
          Text(
            '2. Select Report Types',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('All Reports'),
                  subtitle: const Text('Includes all report types below'),
                  value: _selectedTypes.contains(ExportType.all),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTypes = {ExportType.all};
                      } else {
                        _selectedTypes.remove(ExportType.all);
                      }
                    });
                  },
                  secondary: Icon(Icons.select_all, color: Colors.purple[700]),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  title: const Text('Summary Report'),
                  subtitle: const Text('Overview with key metrics and totals'),
                  value: _selectedTypes.contains(ExportType.summary) ||
                      _selectedTypes.contains(ExportType.all),
                  enabled: !_selectedTypes.contains(ExportType.all),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTypes.add(ExportType.summary);
                      } else {
                        _selectedTypes.remove(ExportType.summary);
                      }
                    });
                  },
                  secondary: Icon(Icons.summarize, color: Colors.blue[700]),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  title: const Text('Detailed Expense Report'),
                  subtitle:
                  const Text('Day-by-day expense breakdown with charts'),
                  value: _selectedTypes.contains(ExportType.detailed) ||
                      _selectedTypes.contains(ExportType.all),
                  enabled: !_selectedTypes.contains(ExportType.all),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTypes.add(ExportType.detailed);
                      } else {
                        _selectedTypes.remove(ExportType.detailed);
                      }
                    });
                  },
                  secondary: Icon(Icons.analytics, color: Colors.green[700]),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  title: const Text('Inventory Report'),
                  subtitle: const Text('Current stock levels and purchases'),
                  value: _selectedTypes.contains(ExportType.inventory) ||
                      _selectedTypes.contains(ExportType.all),
                  enabled: !_selectedTypes.contains(ExportType.all),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTypes.add(ExportType.inventory);
                      } else {
                        _selectedTypes.remove(ExportType.inventory);
                      }
                    });
                  },
                  secondary: Icon(Icons.inventory, color: Colors.orange[700]),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  title: const Text('Usage History'),
                  subtitle: const Text('Complete usage transaction log'),
                  value: _selectedTypes.contains(ExportType.usage) ||
                      _selectedTypes.contains(ExportType.all),
                  enabled: !_selectedTypes.contains(ExportType.all),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTypes.add(ExportType.usage);
                      } else {
                        _selectedTypes.remove(ExportType.usage);
                      }
                    });
                  },
                  secondary: Icon(Icons.history, color: Colors.red[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Preview Info
          Text(
            '3. Export Preview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Text(
                        'Export Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Period', _getPeriodDisplayText()),
                  const SizedBox(height: 8),
                  _buildInfoRow('Reports', _getSelectedTypesText()),
                  const SizedBox(height: 8),
                  _buildInfoRow('Format', 'Microsoft Excel (.xlsx)'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Save Location', 'Downloads folder'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Export Button
          FilledButton.icon(
            onPressed:
            _isExporting || _selectedTypes.isEmpty ? null : _exportToExcel,
            icon: _isExporting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.file_download),
            label: Text(_isExporting
                ? 'Generating Excel...'
                : 'Generate & Download Excel'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green[700],
            ),
          ),
          const SizedBox(height: 16),

          // Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The Excel file will be saved to your Downloads folder. You can open it with Excel, Google Sheets, or any spreadsheet application.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodDisplayText() {
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMMM yyyy');
    final yearFormat = DateFormat('yyyy');

    switch (_selectedPeriod) {
      case ExportPeriod.day:
        return dateFormat.format(_selectedDate);
      case ExportPeriod.month:
        return monthFormat.format(_selectedDate);
      case ExportPeriod.year:
        return yearFormat.format(_selectedDate);
      case ExportPeriod.custom:
        return '${dateFormat.format(_customStartDate)} to ${dateFormat.format(_customEndDate)}';
    }
  }

  String _getSelectedTypesText() {
    if (_selectedTypes.contains(ExportType.all)) {
      return 'All Reports (4 sheets)';
    }
    if (_selectedTypes.isEmpty) {
      return 'None selected';
    }
    return '${_selectedTypes.length} report${_selectedTypes.length > 1 ? 's' : ''} selected';
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

// Help Dialog
class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excel Export Guide'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Report Types:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              'Summary Report',
              'Overview of expenses, items, and key metrics. Perfect for quick analysis.',
            ),
            _buildHelpItem(
              'Detailed Expense',
              'Day-by-day breakdown of expenses with product-wise distribution.',
            ),
            _buildHelpItem(
              'Inventory Report',
              'Complete list of all items with purchase details and remaining stock.',
            ),
            _buildHelpItem(
              'Usage History',
              'Transaction log of all usage entries with dates and amounts.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Excel Features:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '• Professional formatting with headers\n'
                  '• Color-coded sections\n'
                  '• Auto-fitted columns\n'
                  '• Formulas for totals and averages\n'
                  '• Multiple sheets in one file\n'
                  '• Compatible with Excel & Google Sheets',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.trip_origin_outlined,
                      size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Select "All Reports" for comprehensive documentation.',
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
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
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// Month-Year Picker
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

// Year Picker
class _YearPicker extends StatefulWidget {
  final int initialYear;
  final Function(int) onYearSelected;

  const _YearPicker({
    required this.initialYear,
    required this.onYearSelected,
  });

  @override
  State<_YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  late int selectedYear;
  final int startYear = 2020;
  late final int endYear;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialYear;
    endYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final years =
    List.generate(endYear - startYear + 1, (index) => startYear + index);

    return AlertDialog(
      title: const Text('Select Year'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            final isSelected = year == selectedYear;
            return InkWell(
              onTap: () => setState(() => selectedYear = year),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    year.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onYearSelected(selectedYear);
            Navigator.pop(context);
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
