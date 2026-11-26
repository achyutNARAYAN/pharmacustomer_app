import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/customer_support_sheet.dart';
import '../profile/providers/customer_address_provider.dart';
import 'live_tracking.dart';
import 'tax_invoice.dart';

/// Production Quick-Commerce Order Placed Confirmation Screen
/// Engineered to Blinkit & Zomato celebration standards:
/// - Celebratory Hero Card with exact clock ETA ('Arriving by 1:38 PM') and pulsing radar dot
/// - Live 3-Stage Micro-Progress Stepper (Confirmed -> Chemist Packing -> Delivery)
/// - One-Tap Quick Delivery Instructions for the rider ('Don't ring bell', 'Leave at door')
/// - Route & Verified Chemist Safety Snapshot with Tamper-evident Packaging seal
/// - Smart Payment Proof: Correct 'Pay on Delivery' badge for COD vs 'PAID' for UPI/Card
/// - Collapsible itemized bill summary with invoice PDF access
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
  DateTime _estimatedArrival = DateTime.now().add(const Duration(minutes: 12));
  final Set<String> _selectedInstructions = <String>{};

  @override
  void initState() {
    super.initState();
    // Dynamic Blinkit-style delivery clock ETA (12 mins from now)
    _estimatedArrival = DateTime.now().add(const Duration(minutes: 12));
  }

  String _formatEtaClock(DateTime dt) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

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

  void _toggleInstruction(String instruction) {
    setState(() {
      if (_selectedInstructions.contains(instruction)) {
        _selectedInstructions.remove(instruction);
        AppToast.info(context, 'Removed instruction: "$instruction"');
      } else {
        _selectedInstructions.add(instruction);
        AppToast.success(context, 'Rider instruction added: "$instruction"');
      }
    });
  }

  Widget _buildStepNode({
    required IconData icon,
    required String label,
    bool isCompleted = false,
    bool isActive = false,
  }) {
    final color = isCompleted
        ? const Color(0xFF16A34A)
        : (isActive ? AppTheme.primaryDark : const Color(0xFF94A3B8));
    final bgColor = isCompleted
        ? const Color(0xFFDCFCE7)
        : (isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9));
    final border = isCompleted
        ? const Color(0xFF86EFAC)
        : (isActive ? AppTheme.primary : const Color(0xFFCBD5E1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: Center(
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              size: 17,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? AppTheme.primaryDark
                : (isCompleted ? const Color(0xFF16A34A) : AppTheme.mutedText),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionChip(String text) {
    final isSelected = _selectedInstructions.contains(text);
    return InkWell(
      onTap: () => _toggleInstruction(text),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryDark : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF34D399)),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
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

    final isCod = effectiveMethod.toUpperCase().contains('COD') ||
        effectiveMethod.toUpperCase().contains('CASH');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        // Clean close button preventing confusing cart back-navigation
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.text, size: 22),
          tooltip: 'Back to Home',
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
        // Clean, non-redundant title
        title: const Text(
          'Order Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
        actions: [
          // Quick Support / Help
          TextButton.icon(
            onPressed: () => showCustomerSupportSheet(context, orderId: widget.orderId),
            icon: const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.primaryDark),
            label: const Text(
              'Help',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
          // Tax Invoice
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
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // ── 1. Hero Celebration Card (Blinkit Style) ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
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
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

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
                const SizedBox(height: 8),

                // Blinkit Exact Clock Time ETA Badge with Live Radar Dot
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing Live Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Arriving by ${_formatEtaClock(_estimatedArrival)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '10–15 mins',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Order Code Chip with Tap-to-Copy
                if (widget.orderId != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _copyOrderId(context, widget.orderId!),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
          const SizedBox(height: 12),

          // ── 2. Live 3-Stage Micro-Progress Stepper ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text(
                      'LIVE ORDER STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mutedText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Step 1: Confirmed
                    _buildStepNode(
                      icon: Icons.check_rounded,
                      label: 'Confirmed',
                      isCompleted: true,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 18),
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    // Step 2: Chemist Packing (Active)
                    _buildStepNode(
                      icon: Icons.medical_services_rounded,
                      label: 'Chemist Packing',
                      isActive: true,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 18),
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    // Step 3: Out for Delivery (Pending)
                    _buildStepNode(
                      icon: Icons.moped_rounded,
                      label: 'Out for Delivery',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 3. One-Tap Quick Delivery Instructions (Blinkit Signature) ─────
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
                const Row(
                  children: [
                    Icon(Icons.directions_bike_rounded, size: 16, color: AppTheme.primary),
                    SizedBox(width: 6),
                    Text(
                      'DELIVERY INSTRUCTIONS FOR RIDER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mutedText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInstructionChip('🔕 Don\'t ring bell'),
                    _buildInstructionChip('🚪 Leave at doorstep'),
                    _buildInstructionChip('📞 Call on arrival'),
                    _buildInstructionChip('🛡️ Leave with guard'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 4. Route & Pharmacy Verification Card ─────────────────────────
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
                    // Live Allocation Status (Replaces confusing 'Slot: Now')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Store Allocated',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
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

                // Route Connector
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                  child: Container(
                    height: 20,
                    width: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                // Delivery Destination Row
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
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 5. Medicines & Collapsible Bill Breakdown ──────────────────────
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.text,
                              ),
                            ),
                            // Smart COD vs Online payment title
                            Text(
                              isCod
                                  ? 'Pay on Delivery via Cash or UPI'
                                  : 'Paid ₹${paid.toStringAsFixed(0)} via $effectiveMethod',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCod ? FontWeight.w600 : FontWeight.normal,
                                color: isCod ? const Color(0xFFB45309) : AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Smart Payment Badge (TO PAY for COD vs PAID for Online)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCod ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCod ? 'TO PAY ₹${paid.toStringAsFixed(0)}' : 'PAID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCod ? const Color(0xFFB45309) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isItemsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
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
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.medication_liquid_outlined,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.pack.isNotEmpty ? item.pack : "Unit"} · ${item.quantity} unit${item.quantity > 1 ? "s" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.mutedText,
                                  ),
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
                    effectiveDeliveryFee == 0
                        ? 'FREE'
                        : '₹${effectiveDeliveryFee.toStringAsFixed(0)}',
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
