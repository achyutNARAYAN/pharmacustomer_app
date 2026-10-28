import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../cart/live_tracking.dart';
import '../cart/tax_invoice.dart';
import '../home/search.dart';
import 'providers/orders_provider.dart';
import 'repositories/orders_repository.dart';

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});
  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final orders = ordersProvider.orders;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Order History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${orders.length} orders',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: orders.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No orders placed yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When you place medicine or health orders, they will appear here with live tracking and tax invoices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.mutedText, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const Search()),
                      ),
                      icon: const Icon(Icons.shopping_basket_outlined),
                      label: const Text('Browse Medicines'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                    hintText: 'Search medicine, order ID, or doctor...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppTheme.outlineBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppTheme.outlineBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Delivered', 'Prescription Orders', 'Refills']
                        .map(
                          (value) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(value),
                              selected: filter == value,
                              onSelected: (_) => setState(() => filter = value),
                              backgroundColor: Colors.white,
                              selectedColor: Colors.white,
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: filter == value
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                              side: BorderSide(
                                color: filter == value
                                    ? AppTheme.primary
                                    : AppTheme.outlineBorder,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 18),
                ...orders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _OrderCard(
                      id: '#${order.orderId}',
                      status: _formatOrderStatus(order.status),
                      total: '₹${(order.totalPaise / 100).toStringAsFixed(0)}',
                      items: [
                        '${order.itemCount} item(s) ordered · Placed ${_formatDate(order.createdAt)}',
                      ],
                      primary: order.isActive,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return 'Order Placed · Processing';
      case OrderStatus.confirmed:
        return 'Confirmed by Pharmacist';
      case OrderStatus.processing:
        return 'Packing at Hub';
      case OrderStatus.outForDelivery:
        return 'Out for Express Delivery';
      case OrderStatus.delivered:
        return 'Delivered Successfully';
      case OrderStatus.cancelled:
        return 'Order Cancelled';
      case OrderStatus.rejected:
        return 'Order Rejected';
      case OrderStatus.refunded:
        return 'Payment Refunded';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.id,
    required this.status,
    required this.total,
    required this.items,
    this.primary = false,
  });
  final String id, status, total;
  final List<String> items;
  final bool primary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.outlineBorder),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.successText, size: 17),
                  const SizedBox(width: 7),
                  Expanded(child: Text(status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.successText, fontWeight: FontWeight.w700, fontSize: 14),
                  )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              total,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(Icons.tag, size: 15, color: AppTheme.mutedText),
            const SizedBox(width: 4),
            Text(
              id,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const Divider(height: 24),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 7, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 13, height: 1.35, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const TaxInvoice()),
                ),
                icon: const Icon(Icons.description_outlined, size: 19),
                label: const Text('Invoice'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LiveTracking()),
                ),
                icon: const Icon(Icons.route_outlined, size: 19),
                label: const Text('Track order'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ],
        ),
        if (primary) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.replay_rounded, size: 19),
              label: const Text('Reorder'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ),
        ],
      ],
    ),
  );
}
