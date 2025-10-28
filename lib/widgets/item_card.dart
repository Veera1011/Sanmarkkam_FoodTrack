import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';
import '../providers/items_provider.dart';
import '../providers/auth_provider.dart';

class ItemCard extends ConsumerStatefulWidget {
  final FoodItem item;

  const ItemCard({super.key, required this.item});

  @override
  ConsumerState<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<ItemCard> {
  FoodItem? _previousMonthItem;
  bool _isLoadingPrevious = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isCarriedForward &&
        widget.item.previousMonthItemId != null) {
      _loadPreviousMonthItem();
    }
  }

  Future<void> _loadPreviousMonthItem() async {
    setState(() => _isLoadingPrevious = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final previous =
      await ref.read(firestoreServiceProvider).getPreviousMonthItem(
        user.uid,
        widget.item.previousMonthItemId!,
      );
      if (mounted) {
        setState(() {
          _previousMonthItem = previous;
          _isLoadingPrevious = false;
        });
      }
    } catch (e) {
      print('Error loading previous month item: $e');
      if (mounted) {
        setState(() => _isLoadingPrevious = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingAsync =
    ref.watch(itemRemainingQuantityProvider(widget.item.id));
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.item.isMonthClosed
                        ? Colors.grey[300]
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fastfood,
                    color: widget.item.isMonthClosed
                        ? Colors.grey[600]
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                color: widget.item.isMonthClosed
                                    ? Colors.grey[700]
                                    : null,
                              ),
                            ),
                          ),
                          if (widget.item.isMonthClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 12, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'CLOSED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widget.item.isCarriedForward) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.forward,
                                      size: 10, color: Colors.blue[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Carried Forward',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              'Month: ${monthFormat.format(widget.item.datePurchased)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: widget.item.isMonthClosed
                                    ? Colors.grey[600]
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.item.isCarriedForward) ...[
                        const SizedBox(height: 4),
                        if (_isLoadingPrevious)
                          Row(
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Loading origin...',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          )
                        else if (_previousMonthItem != null)
                          Text(
                            '📦 From ${monthFormat.format(_previousMonthItem!.datePurchased)} (Originally ${_previousMonthItem!.quantityPurchased.toStringAsFixed(2)} kg)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            '📦 From previous month',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    label: 'Purchased',
                    value:
                    '${widget.item.quantityPurchased.toStringAsFixed(2)} kg',
                    icon: Icons.shopping_cart,
                    isGrayed: widget.item.isMonthClosed,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    label: 'Unit Price',
                    value: currencyFormat.format(widget.item.unitPrice),
                    icon: Icons.currency_rupee,
                    isGrayed: widget.item.isMonthClosed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Date: ${dateFormat.format(widget.item.datePurchased)}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.item.isMonthClosed
                      ? Colors.grey[500]
                      : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 12),
            remainingAsync.when(
              data: (remaining) {
                final percentage = widget.item.quantityPurchased > 0
                    ? (remaining / widget.item.quantityPurchased) * 100
                    : 0;
                final color = percentage > 50
                    ? Colors.green
                    : percentage > 20
                    ? Colors.orange
                    : Colors.red;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.item.isMonthClosed
                              ? 'Final Stock'
                              : 'Remaining Stock',
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: widget.item.isMonthClosed
                                ? Colors.grey[600]
                                : null,
                          ),
                        ),
                        Text(
                          '${remaining.toStringAsFixed(2)} kg',
                          style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: widget.item.isMonthClosed
                                ? Colors.grey[700]
                                : color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.item.quantityPurchased > 0
                            ? remaining / widget.item.quantityPurchased
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.item.isMonthClosed ? Colors.grey : color,
                        ),
                      ),
                    ),
                    if (widget.item.isMonthClosed && remaining > 0.01) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.forward,
                                size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${remaining.toStringAsFixed(2)} kg carried to ${monthFormat.format(DateTime(widget.item.datePurchased.year, widget.item.datePurchased.month + 1, 1))}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.item.isMonthClosed) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock, size: 14, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Month closed - No further changes allowed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isGrayed;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isGrayed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isGrayed ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isGrayed ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isGrayed ? Colors.grey[700] : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
