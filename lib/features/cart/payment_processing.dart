import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/theme.dart';
import '../orders/providers/orders_provider.dart';
import '../orders/repositories/orders_repository.dart';
import 'order_placed.dart';

class PaymentProcessing extends StatefulWidget {
  const PaymentProcessing({super.key, required this.amount});
  final double amount;

  @override
  State<PaymentProcessing> createState() => _PaymentProcessingState();
}

class _PaymentProcessingState extends State<PaymentProcessing> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  void _processPayment() {
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;

      final cart = context.read<CartNotifier>();
      final ordersProvider = context.read<OrdersProvider?>();

      // 1. Snapshot the confirmed order details
      final orderedItems = List<CartItem>.from(cart.items);
      final totalPaid = widget.amount;
      final totalCount = cart.totalCount > 0 ? cart.totalCount : orderedItems.length;

      // 2. Record in OrdersProvider
      final orderId = 'AC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      ordersProvider?.addOrder(
        OrderItem(
          orderId: orderId,
          status: OrderStatus.placed,
          totalPaise: (totalPaid * 100).round(),
          itemCount: totalCount,
          createdAt: DateTime.now(),
        ),
      );

      // 3. Atomically clear the active cart (remote API DELETE + local persistence wipe)
      cart.clearAll();

      // 4. Auto-transition to Order Placed confirmation with the confirmed snapshot
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderPlaced(
            orderedItems: orderedItems,
            totalPaid: totalPaid,
            totalCount: totalCount,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '✚  pharmaCustomer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const Spacer(),
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 28),
          const Text(
            'Securing Payment &\nProcessing Order…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Please keep this screen open while we confirm with your bank.'),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.outlineBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MERCHANT ENTITY',
                  style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                ),
                const Text(
                  'pharmaCustomer Health Technologies Ltd.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order total · ₹${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppTheme.mutedText),
                SizedBox(width: 6),
                Text(
                  '128-bit Encrypted Banking Handshake',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
