import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/errors/failures.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../orders/providers/orders_provider.dart';
import 'order_placed.dart';

class PaymentProcessing extends StatefulWidget {
  const PaymentProcessing({
    super.key,
    required this.amount,
    this.method = 'UPI',
  });
  final double amount;
  final String method;

  @override
  State<PaymentProcessing> createState() => _PaymentProcessingState();
}

class _PaymentProcessingState extends State<PaymentProcessing> {
  bool _isProcessing = true;
  bool _requestInFlight = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPayment();
    });
  }

  Future<void> _processPayment() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final cart = context.read<CartNotifier>();
    final ordersProvider = context.read<OrdersProvider>();

    // Snapshot current cart state for confirmation display
    final orderedItems = List<CartItem>.from(cart.items);
    final totalPaid = widget.amount;
    final totalCount = cart.totalCount > 0 ? cart.totalCount : orderedItems.length;
    final itemsTotal = cart.itemsTotalPaise > 0
        ? (cart.itemsTotalPaise / 100.0)
        : orderedItems.fold<double>(0.0, (sum, i) => sum + i.total);
    final discount = cart.discountPaise > 0 ? (cart.discountPaise / 100.0) : 0.0;
    final deliveryFee = (cart.deliveryFeePaise / 100.0);
    final couponCode = cart.couponCode;
    final allocatedStore = cart.allocatedStore;

    final isCod = widget.method.toUpperCase().contains('COD') ||
        widget.method.toUpperCase().contains('CASH');
    final paymentMethodParam = isCod ? 'COD' : 'ONLINE';

    try {
      // Minimum visual handshake delay for banking security feel
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;

      OrderModel? placedOrder;
      if (ApiService.token != null) {
        placedOrder = await ordersProvider.placeOrder(
          paymentMethod: paymentMethodParam,
        );
      }

      if (!mounted) return;

      // Atomically clear active cart once order is confirmed by server
      cart.clearAll();

      final resolvedOrderId = placedOrder?.orderCode.isNotEmpty == true
          ? placedOrder!.orderCode
          : placedOrder?.id;

      // Navigate to order confirmation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderPlaced(
            orderId: resolvedOrderId,
            orderedItems: orderedItems,
            totalPaid: placedOrder != null ? (placedOrder.totalPayablePaise / 100.0) : totalPaid,
            totalCount: totalCount,
            itemsTotal: itemsTotal,
            discount: discount,
            deliveryFee: deliveryFee,
            couponCode: couponCode,
            allocatedStore: allocatedStore,
            paymentMethod: widget.method,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _requestInFlight = false;
      setState(() {
        _isProcessing = false;
        _errorMessage = e is Failure ? e.message : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
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
          if (_isProcessing) ...[
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 28),
            const Text(
              'Securing Payment &\nConfirming Order…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Please keep this screen open while we connect with pharmacy.'),
          ] else ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order Placement Failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'An unexpected network error occurred while placing your order.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Review'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _processPayment,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Placement'),
                ),
              ],
            ),
          ],
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
        ],
      ),
    ),
  );
}
