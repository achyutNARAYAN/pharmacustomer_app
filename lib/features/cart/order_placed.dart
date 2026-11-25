import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';
import '../orders/models/order_model.dart';
import '../orders/widgets/order_timeline_stepper.dart';
import '../profile/providers/customer_address_provider.dart';
import 'tax_invoice.dart';
import 'live_tracking.dart';

class OrderPlaced extends StatelessWidget {
  final String? orderId;
  final List<CartItem>? orderedItems;
  final double? totalPaid;
  final int? totalCount;
  final double? itemsTotal;
  final double? discount;
  final double? deliveryFee;
  final String? couponCode;
  final String? allocatedStore;
  final String? paymentMethod;

  const OrderPlaced({
    super.key,
    this.orderId,
    this.orderedItems,
    this.totalPaid,
    this.totalCount,
    this.itemsTotal,
    this.discount,
    this.deliveryFee,
    this.couponCode,
    this.allocatedStore,
    this.paymentMethod,
  });

  String _formatPharmacyName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final words = raw.trim().split(RegExp(r'\s+'));
    if (words.length <= 2) return words.join(' ');
    return '${words[0]} ${words[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final profile = context.watch<ProfileNotifier>();

    CustomerAddressProvider? addressProvider;
    try {
      addressProvider = Provider.of<CustomerAddressProvider>(context, listen: false);
    } catch (_) {}

    final activeAddress = addressProvider?.selectedAddress ?? addressProvider?.defaultAddress;
    final deliveryAddress = activeAddress != null
        ? activeAddress.displayDetails
        : ((profile.address.isNotEmpty && profile.address != 'Set delivery location')
            ? profile.address
            : 'Primary Delivery Location');

    final items = orderedItems ?? cart.items;
    final count = totalCount ??
        (orderedItems != null
            ? orderedItems!.fold<int>(0, (sum, i) => sum + i.quantity)
            : cart.totalCount);
    final paid = totalPaid ?? cart.totalPrice;

    final effectiveItemsTotal = itemsTotal ??
        (cart.itemsTotalPaise > 0
            ? (cart.itemsTotalPaise / 100.0)
            : items.fold<double>(0.0, (sum, i) => sum + i.total));
    final effectiveDiscount = discount ?? (cart.discountPaise / 100.0);
    final effectiveDeliveryFee = deliveryFee ??
        (cart.deliveryFeePaise > 0 ? (cart.deliveryFeePaise / 100.0) : 40.0);
    final effectiveCoupon = couponCode ?? cart.couponCode;
    final effectiveStore = allocatedStore ?? cart.allocatedStore;
    final effectiveMethod = paymentMethod ?? 'UPI';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ORDER CONFIRMED',
              style: TextStyle(fontSize: 10, color: AppTheme.mutedText, letterSpacing: .5),
            ),
            Text(
              'Processing Order',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TaxInvoice(
                  orderId: orderId,
                  items: items,
                  totalPaid: paid,
                  orderDate: DateTime.now(),
                  itemsTotal: effectiveItemsTotal,
                  discount: effectiveDiscount,
                  deliveryFee: effectiveDeliveryFee,
                  couponCode: effectiveCoupon,
                  allocatedStore: effectiveStore,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'View Invoice',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          // ── Card 1: Order Status Confirmation ─────────────────────────────
          _card(
            Column(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.surfaceLow,
                  child: Icon(
                    Icons.check_circle,
                    size: 36,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Payment Confirmed Order placed successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (orderId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Order ID: #$orderId',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const OrderTimelineStepper(
                  status: OrderStatus.ORDER_PLACED,
                  isCompact: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Card 2: Express Delivery Slot & Pharmacy (Matches Order Review) ──
          _card(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(Icons.local_shipping_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Express Delivery Slot',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Confirmed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        deliveryAddress,
                        style: const TextStyle(color: AppTheme.mutedText, height: 1.35),
                      ),
                      if (effectiveStore != null && effectiveStore.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.storefront_outlined, size: 15, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Pharmacy: ${_formatPharmacyName(effectiveStore)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Card 3: Medicines & Complete FinTech Bill Breakdown ─────────────
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medicines $count items',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 26),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _iconBox(Icons.medication_outlined, small: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.pack} · ${item.quantity} unit',
                                style: const TextStyle(color: AppTheme.mutedText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${item.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                _row('Items total', '₹${effectiveItemsTotal.toStringAsFixed(0)}'),
                if (effectiveDiscount > 0) ...[
                  _row(
                    effectiveCoupon != null && effectiveCoupon.isNotEmpty
                        ? 'Coupon discount ($effectiveCoupon)'
                        : 'Prescription subsidy & discount',
                    '−₹${effectiveDiscount.toStringAsFixed(0)}',
                    green: true,
                  ),
                ],
                _row(
                  'Express delivery',
                  effectiveDeliveryFee == 0
                      ? 'FREE'
                      : '₹${effectiveDeliveryFee.toStringAsFixed(0)}',
                  green: effectiveDeliveryFee == 0,
                ),
                _row('Handling & packaging', 'FREE', green: true),
                _row('Taxes (GST included)', 'Included'),
                const Divider(height: 24),
                _row(
                  'Total paid',
                  '₹${paid.toStringAsFixed(0)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Card 4: Payment Method (Matches Order Review) ───────────────────
          _card(
            Row(
              children: [
                _iconBox(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment method',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Paid via $effectiveMethod · Completed',
                        style: const TextStyle(color: AppTheme.mutedText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LiveTracking(),
              ),
            ),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Track Live Delivery'),
          ),
        ),
      ),
    );
  }
}

Widget _card(Widget child) => Material(
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: const BorderSide(color: AppTheme.outlineBorder),
  ),
  clipBehavior: Clip.antiAlias,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

Widget _iconBox(IconData icon, {bool small = false}) => Container(
  width: small ? 38 : 48,
  height: small ? 38 : 48,
  decoration: BoxDecoration(color: AppTheme.surfaceLow, borderRadius: BorderRadius.circular(14)),
  child: Icon(icon, color: AppTheme.primary, size: small ? 21 : 25),
);

Widget _row(String label, String value, {bool bold = false, bool green = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, height: 1.3))),
    const SizedBox(width: 12),
    Text(
      value,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: green ? AppTheme.successText : (bold ? AppTheme.primaryDark : AppTheme.text),
      ),
    ),
  ]),
);
