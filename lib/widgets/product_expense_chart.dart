import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProductExpenseChart extends StatelessWidget {
  final Map<String, Map<String, dynamic>> productExpenses;

  const ProductExpenseChart({super.key, required this.productExpenses});

  @override
  Widget build(BuildContext context) {
    if (productExpenses.isEmpty) {
      return Center(
        child: Text(
          'No product data available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    // Calculate total expense
    final totalExpense = productExpenses.values.fold<double>(
      0.0,
          (sum, product) => sum + (product['totalExpense'] as double),
    );

    // Sort products by expense (descending)
    final sortedProducts = productExpenses.entries.toList()
      ..sort((a, b) => (b.value['totalExpense'] as double).compareTo(a.value['totalExpense'] as double));

    // Generate colors
    final colors = _generateColors(sortedProducts.length);

    return Row(
      children: [
        // Pie Chart
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _PieChartPainter(
                products: sortedProducts,
                totalExpense: totalExpense,
                colors: colors,
              ),
            ),
          ),
        ),
        // Legend
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedProducts.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                final expense = product.value['totalExpense'] as double;
                final percentage = (expense / totalExpense * 100).toStringAsFixed(1);
                final quantity = product.value['totalQuantity'] as double;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.value['name'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '₹${expense.toStringAsFixed(0)} ($percentage%) • ${quantity.toStringAsFixed(1)}kg',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<Color> _generateColors(int count) {
    return List.generate(count, (index) {
      final hue = (index * 360 / count) % 360;
      return HSLColor.fromAHSL(1.0, hue, 0.7, 0.6).toColor();
    });
  }
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<String, Map<String, dynamic>>> products;
  final double totalExpense;
  final List<Color> colors;

  _PieChartPainter({
    required this.products,
    required this.totalExpense,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < products.length; i++) {
      final expense = products[i].value['totalExpense'] as double;
      final sweepAngle = (expense / totalExpense) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);

    // Draw total in center
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '₹${totalExpense.toStringAsFixed(0)}\n',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const TextSpan(
            text: 'Total',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}