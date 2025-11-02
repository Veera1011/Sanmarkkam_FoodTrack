// lib/services/excel_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../models/food_item.dart';
import '../models/usage_entry.dart';
import '../providers/usage_provider.dart';

class ExcelService {
  // Save file to Downloads folder using MediaStore (Android 10+)
  Future<String> saveToDownloads(List<int> bytes, String filename) async {
    if (Platform.isAndroid) {
      // Use Android MediaStore API through platform channel
      const platform =
      MethodChannel('com.example.sanmarkkam_foodtrack/storage');

      try {
        final result = await platform.invokeMethod('saveToDownloads', {
          'filename': filename,
          'bytes': Uint8List.fromList(bytes),
          'mimeType':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        });

        return result as String;
      } catch (e) {
        // Fallback to traditional method if platform channel fails
        return await _saveFallback(bytes, filename);
      }
    } else {
      // For iOS or other platforms
      return await _saveFallback(bytes, filename);
    }
  }

  Future<String> _saveFallback(List<int> bytes, String filename) async {
    final directory = await getExternalStorageDirectory();
    final downloadDir = Directory('/storage/emulated/0/Download');

    if (await downloadDir.exists()) {
      final file = File('${downloadDir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } else {
      final file = File('${directory!.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  // Add Summary Sheet
  void addSummarySheet(
      Excel excel,
      List<FoodItem> items,
      List<UsageEntry> usage,
      DateRange dateRange,
      ) {
    final sheet = excel['Summary'];
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    // Calculate metrics
    final totalExpense = usage.fold<double>(0.0, (sum, e) => sum + e.expense);
    final totalItems = items.length;
    final totalQuantityPurchased =
    items.fold<double>(0.0, (sum, item) => sum + item.quantityPurchased);
    final totalQuantityUsed =
    usage.fold<double>(0.0, (sum, e) => sum + e.quantityUsed);
    final avgExpensePerDay =
    usage.isEmpty ? 0.0 : totalExpense / _getDaysDifference(dateRange);

    // Product-wise expense
    final Map<String, double> productExpenses = {};
    for (final entry in usage) {
      final item = items.firstWhere((i) => i.id == entry.itemId,
          orElse: () => FoodItem(
            id: entry.itemId,
            name: 'Unknown',
            quantityPurchased: 0,
            unitPrice: 0,
            datePurchased: DateTime.now(),
          ));
      productExpenses[item.name] =
          (productExpenses[item.name] ?? 0) + entry.expense;
    }

    int row = 0;

    // Title
    _setCell(sheet, row, 0, 'SANMARKKAM FOODTRACK - SUMMARY REPORT');
    _mergeCells(sheet, row, 0, row, 4);
    _styleHeader(sheet, row, 0, fontSize: 16);
    row += 2;

    // Period
    _setCell(sheet, row, 0, 'Period:');
    _setCell(sheet, row, 1,
        '${dateFormat.format(dateRange.start)} to ${dateFormat.format(dateRange.end)}');
    _styleBold(sheet, row, 0);
    row++;

    _setCell(sheet, row, 0, 'Generated:');
    _setCell(
        sheet, row, 1, DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()));
    _styleBold(sheet, row, 0);
    row += 2;

    // Key Metrics Section
    _setCell(sheet, row, 0, 'KEY METRICS');
    _mergeCells(sheet, row, 0, row, 4);
    _styleHeader(sheet, row, 0);
    row++;

    final metrics = [
      ['Total Expense', currencyFormat.format(totalExpense)],
      ['Total Items', totalItems.toString()],
      ['Total Transactions', usage.length.toString()],
      ['Quantity Purchased', '${totalQuantityPurchased.toStringAsFixed(2)} kg'],
      ['Quantity Used', '${totalQuantityUsed.toStringAsFixed(2)} kg'],
      ['Average Daily Expense', currencyFormat.format(avgExpensePerDay)],
    ];

    for (final metric in metrics) {
      _setCell(sheet, row, 0, metric[0]);
      _setCell(sheet, row, 1, metric[1]);
      _styleBold(sheet, row, 0);
      row++;
    }
    row++;

    // Product-wise Expense
    _setCell(sheet, row, 0, 'PRODUCT-WISE EXPENSE');
    _mergeCells(sheet, row, 0, row, 4);
    _styleHeader(sheet, row, 0);
    row++;

    _setCell(sheet, row, 0, 'Product');
    _setCell(sheet, row, 1, 'Expense');
    _setCell(sheet, row, 2, 'Percentage');
    _styleHeader(sheet, row, 0);
    _styleHeader(sheet, row, 1);
    _styleHeader(sheet, row, 2);
    row++;

    final sortedProducts = productExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final product in sortedProducts) {
      final percentage =
      (product.value / totalExpense * 100).toStringAsFixed(1);
      _setCell(sheet, row, 0, product.key);
      _setCell(sheet, row, 1, currencyFormat.format(product.value));
      _setCell(sheet, row, 2, '$percentage%');
      row++;
    }

    // Auto-fit columns
    _autoFitColumns(sheet, 5);
  }

  // Add Detailed Expense Sheet
  void addDetailedExpenseSheet(
      Excel excel,
      List<FoodItem> items,
      List<UsageEntry> usage,
      DateRange dateRange,
      ) {
    final sheet = excel['Detailed Expense'];
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    // Group by date
    final Map<String, List<UsageEntry>> dateGroups = {};
    for (final entry in usage) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.dateUsed);
      if (!dateGroups.containsKey(dateKey)) {
        dateGroups[dateKey] = [];
      }
      dateGroups[dateKey]!.add(entry);
    }

    final sortedDates = dateGroups.keys.toList()..sort();

    int row = 0;

    // Title
    _setCell(sheet, row, 0, 'DETAILED EXPENSE REPORT');
    _mergeCells(sheet, row, 0, row, 5);
    _styleHeader(sheet, row, 0, fontSize: 16);
    row += 2;

    // Period
    _setCell(sheet, row, 0, 'Period:');
    _setCell(sheet, row, 1,
        '${dateFormat.format(dateRange.start)} to ${dateFormat.format(dateRange.end)}');
    _styleBold(sheet, row, 0);
    row += 2;

    // Day-by-day breakdown
    for (final dateKey in sortedDates) {
      final entries = dateGroups[dateKey]!;
      final date = DateTime.parse(dateKey);
      final dayTotal = entries.fold<double>(0.0, (sum, e) => sum + e.expense);

      // Date Header
      _setCell(sheet, row, 0, dateFormat.format(date));
      _setCell(sheet, row, 1, 'Total: ${currencyFormat.format(dayTotal)}');
      _mergeCells(sheet, row, 0, row, 1);
      _styleHeader(sheet, row, 0, bgColor: '#E3F2FD');
      _styleHeader(sheet, row, 1, bgColor: '#E3F2FD');
      row++;

      // Column headers
      _setCell(sheet, row, 0, 'Item');
      _setCell(sheet, row, 1, 'Quantity');
      _setCell(sheet, row, 2, 'Unit Price');
      _setCell(sheet, row, 3, 'Expense');
      _setCell(sheet, row, 4, 'Stock Month');
      for (int i = 0; i < 5; i++) {
        _styleHeader(sheet, row, i);
      }
      row++;

      // Entries for this day
      for (final entry in entries) {
        final item = items.firstWhere(
              (i) => i.id == entry.itemId,
          orElse: () => FoodItem(
            id: entry.itemId,
            name: 'Unknown',
            quantityPurchased: 0,
            unitPrice: 0,
            datePurchased: DateTime.now(),
          ),
        );

        _setCell(sheet, row, 0, item.name);
        _setCell(sheet, row, 1, '${entry.quantityUsed.toStringAsFixed(2)} kg');
        _setCell(sheet, row, 2,
            currencyFormat.format(entry.expense / entry.quantityUsed));
        _setCell(sheet, row, 3, currencyFormat.format(entry.expense));
        _setCell(
            sheet, row, 4, DateFormat('MMM yyyy').format(item.datePurchased));
        row++;
      }
      row++;
    }

    // Auto-fit columns
    _autoFitColumns(sheet, 6);
  }

  // Add Inventory Sheet
  void addInventorySheet(
      Excel excel,
      List<FoodItem> items,
      List<UsageEntry> usage,
      DateRange dateRange,
      ) {
    final sheet = excel['Inventory'];
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    int row = 0;

    // Title
    _setCell(sheet, row, 0, 'INVENTORY REPORT');
    _mergeCells(sheet, row, 0, row, 7);
    _styleHeader(sheet, row, 0, fontSize: 16);
    row += 2;

    // Period
    _setCell(sheet, row, 0, 'Period:');
    _setCell(sheet, row, 1,
        '${dateFormat.format(dateRange.start)} to ${dateFormat.format(dateRange.end)}');
    _styleBold(sheet, row, 0);
    row += 2;

    // Headers
    final headers = [
      'Item Name',
      'Purchase Date',
      'Month',
      'Quantity Purchased',
      'Unit Price',
      'Total Cost',
      'Used',
      'Remaining',
      'Status'
    ];

    for (int i = 0; i < headers.length; i++) {
      _setCell(sheet, row, i, headers[i]);
      _styleHeader(sheet, row, i);
    }
    row++;

    // Items
    for (final item in items) {
      // Calculate used quantity for this item in its month
      final usedInMonth = usage
          .where((u) =>
      u.itemId == item.id &&
          u.dateUsed.year == item.datePurchased.year &&
          u.dateUsed.month == item.datePurchased.month)
          .fold<double>(0.0, (sum, u) => sum + u.quantityUsed);

      final remaining = item.quantityPurchased - usedInMonth;
      final totalCost = item.quantityPurchased * item.unitPrice;
      final status = item.isMonthClosed
          ? 'CLOSED'
          : remaining <= 0
          ? 'DEPLETED'
          : remaining < item.quantityPurchased * 0.2
          ? 'LOW'
          : 'AVAILABLE';

      _setCell(sheet, row, 0, item.name);
      _setCell(sheet, row, 1, dateFormat.format(item.datePurchased));
      _setCell(sheet, row, 2, monthFormat.format(item.datePurchased));
      _setCell(
          sheet, row, 3, '${item.quantityPurchased.toStringAsFixed(2)} kg');
      _setCell(sheet, row, 4, currencyFormat.format(item.unitPrice));
      _setCell(sheet, row, 5, currencyFormat.format(totalCost));
      _setCell(sheet, row, 6, '${usedInMonth.toStringAsFixed(2)} kg');
      _setCell(sheet, row, 7, '${remaining.toStringAsFixed(2)} kg');
      _setCell(sheet, row, 8, status);

      if (item.isCarriedForward) {
        _styleBold(sheet, row, 0);
      }

      row++;
    }

    row++;

    // Totals
    final totalPurchased =
    items.fold<double>(0.0, (sum, item) => sum + item.quantityPurchased);
    final totalCost = items.fold<double>(
        0.0, (sum, item) => sum + (item.quantityPurchased * item.unitPrice));
    final totalUsed = usage.fold<double>(0.0, (sum, u) => sum + u.quantityUsed);

    _setCell(sheet, row, 0, 'TOTALS');
    _setCell(sheet, row, 3, '${totalPurchased.toStringAsFixed(2)} kg');
    _setCell(sheet, row, 5, currencyFormat.format(totalCost));
    _setCell(sheet, row, 6, '${totalUsed.toStringAsFixed(2)} kg');
    _styleHeader(sheet, row, 0);
    _styleHeader(sheet, row, 3);
    _styleHeader(sheet, row, 5);
    _styleHeader(sheet, row, 6);

    // Auto-fit columns
    _autoFitColumns(sheet, 9);
  }

  // Add Usage History Sheet
  void addUsageHistorySheet(
      Excel excel,
      List<UsageEntry> usage,
      List<FoodItem> items,
      DateRange dateRange,
      ) {
    final sheet = excel['Usage History'];
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final monthFormat = DateFormat('MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    int row = 0;

    // Title
    _setCell(sheet, row, 0, 'USAGE HISTORY');
    _mergeCells(sheet, row, 0, row, 6);
    _styleHeader(sheet, row, 0, fontSize: 16);
    row += 2;

    // Period
    _setCell(sheet, row, 0, 'Period:');
    _setCell(sheet, row, 1,
        '${DateFormat('dd MMM yyyy').format(dateRange.start)} to ${DateFormat('dd MMM yyyy').format(dateRange.end)}');
    _styleBold(sheet, row, 0);
    row++;

    _setCell(sheet, row, 0, 'Total Transactions:');
    _setCell(sheet, row, 1, usage.length.toString());
    _styleBold(sheet, row, 0);
    row += 2;

    // Headers
    final headers = [
      'Date & Time',
      'Item Name',
      'Stock Month',
      'Quantity Used',
      'Unit Price',
      'Expense',
      'Remarks'
    ];

    for (int i = 0; i < headers.length; i++) {
      _setCell(sheet, row, i, headers[i]);
      _styleHeader(sheet, row, i);
    }
    row++;

    // Sort usage by date (most recent first)
    final sortedUsage = List<UsageEntry>.from(usage)
      ..sort((a, b) => b.dateUsed.compareTo(a.dateUsed));

    // Usage entries
    for (final entry in sortedUsage) {
      final item = items.firstWhere(
            (i) => i.id == entry.itemId,
        orElse: () => FoodItem(
          id: entry.itemId,
          name: 'Unknown Item',
          quantityPurchased: 0,
          unitPrice: 0,
          datePurchased: DateTime.now(),
        ),
      );

      final unitPrice = entry.expense / entry.quantityUsed;
      final remarks = item.isCarriedForward ? 'Carried Forward Stock' : '';

      _setCell(sheet, row, 0, dateFormat.format(entry.dateUsed));
      _setCell(sheet, row, 1, item.name);
      _setCell(sheet, row, 2, monthFormat.format(item.datePurchased));
      _setCell(sheet, row, 3, '${entry.quantityUsed.toStringAsFixed(2)} kg');
      _setCell(sheet, row, 4, currencyFormat.format(unitPrice));
      _setCell(sheet, row, 5, currencyFormat.format(entry.expense));
      _setCell(sheet, row, 6, remarks);

      row++;
    }

    row++;

    // Totals
    final totalQuantity =
    usage.fold<double>(0.0, (sum, e) => sum + e.quantityUsed);
    final totalExpense = usage.fold<double>(0.0, (sum, e) => sum + e.expense);

    _setCell(sheet, row, 0, 'TOTALS');
    _setCell(sheet, row, 3, '${totalQuantity.toStringAsFixed(2)} kg');
    _setCell(sheet, row, 5, currencyFormat.format(totalExpense));
    _styleHeader(sheet, row, 0);
    _styleHeader(sheet, row, 3);
    _styleHeader(sheet, row, 5);

    // Auto-fit columns
    _autoFitColumns(sheet, 7);
  }

  // Helper methods
  void _setCell(Sheet sheet, int row, int col, dynamic value) {
    final cell =
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value.toString());
  }

  void _mergeCells(
      Sheet sheet, int startRow, int startCol, int endRow, int endCol) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: startRow),
      CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: endRow),
    );
  }

  void _styleHeader(Sheet sheet, int row, int col,
      {String bgColor = '#4CAF50', int fontSize = 12}) {
    final cell =
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(bgColor),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontSize: fontSize,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  void _styleBold(Sheet sheet, int row, int col) {
    final cell =
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.cellStyle = CellStyle(bold: true);
  }

  void _autoFitColumns(Sheet sheet, int columnCount) {
    for (int i = 0; i < columnCount; i++) {
      sheet.setColumnWidth(i, 18);
    }
  }

  int _getDaysDifference(DateRange dateRange) {
    return dateRange.end.difference(dateRange.start).inDays + 1;
  }
}
