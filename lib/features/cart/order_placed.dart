import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../profile/providers/customer_address_provider.dart';
import 'live_tracking.dart';
import 'tax_invoice.dart';

/// Senior Quick-Commerce Order Placed Confirmation Screen
/// Designed to Blinkit & Zomato celebration standards:
/// - Hero Celebration with live ETA (10-15 mins)
/// - Tap-to-copy Order ID
/// - Route & Pharmacy verification snapshot
/// - Collapsible itemized bill & payment proof
/// - Dual actions: [ Track Live Delivery ] and [ Back to Home ]
class OrderPlaced extends StatefulWidget {
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

  @override
  State<OrderPlaced> createState() => _OrderPlacedState();
}

class _OrderPlacedState extends State<OrderPlaced> {
  bool _isItemsExpanded = false;

  String _formatPharmacyName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'pharmaCustomer Express Pharmacy';
    final words = raw.trim().split(RegExp(r'\s+'));
    if (words.length <= 3) return words.join(' ');
    return '${words[0]} ${words[1]} ${words[2]}';
  }

  void _copyOrderId(BuildContext context, String id) {
    Clipboard.setData(ClipboardData(text: id));
    AppToast.show(
      context,
      'Order ID #$id copied to clipboard',
      icon: Icons.copy_rounded,
      iconColor: const Color(0xFF6EE7B7),
      duration: const Duration(seconds: 2),
    );
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

    final items = widget.orderedItems ?? cart.items;
    final count = widget.totalCount ??
        (widget.orderedItems != null
            ? widget.orderedItems!.fold<int>(0, (sum, i) => sum + i.quantity)
            : cart.totalCount);
    final paid = widget.totalPaid ?? cart.totalPrice;

    final effectiveItemsTotal = widget.itemsTotal ??
        (cart.itemsTotalPaise > 0
            ? (cart.itemsTotalPaise / 100.0)
            : items.fold<double>(0.0, (sum, i) => sum + i.total));
    final effectiveDiscount = widget.discount ?? (cart.discountPaise / 100.0);
    final effectiveDeliveryFee = widget.deliveryFee ??
        (cart.deliveryFeePaise > 0 ? (cart.deliveryFeePaise / 100.0) : 0.0);
    final effectiveCoupon = widget.couponCode ?? cart.couponCode;
    final effectiveStore = widget.allocatedStore ?? cart.allocatedStore;
    final effectiveMethod = widget.paymentMethod ?? 'UPI';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern off-white background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ORDER CONFIRMATION',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.mutedText,
                letterSpacing: 0.6,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Order Placed',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TaxInvoice(
                  orderId: widget.orderId,
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
            icon: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary),
            tooltip: 'View Invoice',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // ── 1. Hero Celebration Card (Blinkit Style) ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Celebration Animated Checkmark Ring
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 46,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Exciting Headline
                const Text(
                  'Order Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 6),

                // Express Delivery ETA Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.moped_rounded, size: 16, color: AppTheme.primaryDark),
                      SizedBox(width: 6),
                      Text(
                        'Express Delivery in 10–15 mins',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Order Code Chip with Tap-to-Copy
                if (widget.orderId != null) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => _copyOrderId(context, widget.orderId!),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Order #${widget.orderId}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 14, color: AppTheme.mutedText),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 2. Route & Pharmacy Verification Card ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Verification Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 13, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'Verified Partner Chemist',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Slot: Now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pharmacy Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 18, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fulfilling Pharmacy',
                            style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _formatPharmacyName(effectiveStore),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Dashed Route Connector
                Padding(
                  padding: const EdgeInsets.only(left: 15, top: 4, bottom: 4),
                  child: Container(
                    height: 18,
                    width: 2,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),

                // Destination Address Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivering To',
                            style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            deliveryAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 3. Medicines & Collapsible Bill Breakdown (Blinkit Style) ───────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Header with Expand Toggle
                InkWell(
                  onTap: () => setState(() => _isItemsExpanded = !_isItemsExpanded),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_outlined, size: 18, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Summary ($count medicines)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text),
                            ),
                            Text(
                              'Paid ₹${paid.toStringAsFixed(0)} via $effectiveMethod',
                              style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PAID',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isItemsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),

                // Expandable Items List
                if (_isItemsExpanded) ...[
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.medication_outlined, size: 14, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  '${item.pack} • Qty: ${item.quantity}',
                                  style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${item.total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _billRow('Items total', '₹${effectiveItemsTotal.toStringAsFixed(0)}'),
                  if (effectiveDiscount > 0)
                    _billRow(
                      effectiveCoupon != null && effectiveCoupon.isNotEmpty
                          ? 'Coupon discount ($effectiveCoupon)'
                          : 'Prescription subsidy & discount',
                      '−₹${effectiveDiscount.toStringAsFixed(0)}',
                      isGreen: true,
                    ),
                  _billRow(
                    'Express delivery',
                    effectiveDeliveryFee == 0 ? 'FREE' : '₹${effectiveDeliveryFee.toStringAsFixed(0)}',
                    isGreen: effectiveDeliveryFee == 0,
                  ),
                  _billRow('Handling & packaging', 'FREE', isGreen: true),
                  _billRow('Taxes (GST included)', 'Included'),
                ],
              ],
            ),
          ),
        ],
      ),

      // ── Dual Bottom Actions (Track vs Home) ───────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primary Action: Live Tracking
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => LiveTracking(orderId: widget.orderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.moped_rounded, size: 20),
                  label: const Text(
                    'Track Live Delivery',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Secondary Action: Back to Home
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _billRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isGreen ? const Color(0xFF16A34A) : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}
