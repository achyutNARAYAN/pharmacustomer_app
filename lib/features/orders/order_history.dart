import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/failures.dart';
import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/customer_support_sheet.dart';
import '../cart/cart.dart';
import '../cart/live_tracking.dart';
import '../cart/tax_invoice.dart';
import '../home/search.dart';
import 'providers/orders_provider.dart';
import 'widgets/order_timeline_stepper.dart';

/// Senior Production-Grade Order History matching Blinkit, Zomato & Zepto standards:
/// - Pinned Active Orders with live tracking & doorstep OTP
/// - Clean Past Orders archive with 1-tap Reorder
/// - Detailed modal sheet for deep receipt & timeline inspection
class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});
  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> with WidgetsBindingObserver {
  String filter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _realtimePollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrdersProvider>().fetchOrders(silent: true);
        _syncRealtimeTimer();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<OrdersProvider>().fetchOrders(silent: true);
      _syncRealtimeTimer();
    } else if (state == AppLifecycleState.paused) {
      _realtimePollTimer?.cancel();
      _realtimePollTimer = null;
    }
  }

  void _syncRealtimeTimer() {
    if (!mounted) return;
    final provider = context.read<OrdersProvider>();
    final hasActive = provider.orders.any((o) => o.isActive);

    if (hasActive) {
      _realtimePollTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final prov = context.read<OrdersProvider>();
        if (prov.orders.any((o) => o.isActive)) {
          prov.fetchOrders(silent: true);
        } else {
          _realtimePollTimer?.cancel();
          _realtimePollTimer = null;
        }
      });
    } else {
      _realtimePollTimer?.cancel();
      _realtimePollTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimePollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleReorder(BuildContext context, OrderModel order) {
    final cart = context.read<CartNotifier>();
    for (final item in order.items) {
      cart.add(CartItem(
        id: item.medicineId.isNotEmpty ? item.medicineId : item.name,
        name: item.name,
        pack: item.pack,
        price: item.price,
        quantity: item.quantity,
        requiresPrescription: item.isPrescriptionRequired,
      ));
    }

    AppToast.cart(
      context,
      '${order.items.length} medicines added to your cart',
      onViewCart: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const Cart()),
        );
      },
    );
  }

  void _showCancelOrderDialog(BuildContext context, OrderModel order) {
    String selectedReason = 'CUSTOMER_CHANGED_MIND';
    final noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(dialogCtx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancel Order #${order.orderId}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Orders can only be cancelled before chemist starts packing.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('Select reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              ...[
                {'code': 'CUSTOMER_CHANGED_MIND', 'label': 'Changed my mind'},
                {'code': 'ORDERED_BY_MISTAKE', 'label': 'Ordered by mistake'},
                {'code': 'DELIVERY_DELAYED', 'label': 'Delivery is delayed'},
                {'code': 'OTHER', 'label': 'Other reason'},
              ].map((r) {
                final isSelected = selectedReason == r['code'];
                return InkWell(
                  onTap: () => setSheetState(() => selectedReason = r['code']!),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppTheme.primary : AppTheme.mutedText,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          r['label']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  hintText: 'Optional cancellation note...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setSheetState(() => isSubmitting = true);
                          try {
                            final ordersProvider = context.read<OrdersProvider>();
                            await ordersProvider.cancelOrder(
                              orderId: order.orderId,
                              reason: selectedReason,
                              note: noteController.text.trim(),
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (context.mounted) {
                              AppToast.success(context, 'Order cancelled successfully.');
                            }
                          } catch (e) {
                            setSheetState(() => isSubmitting = false);
                            final msg = e is Failure ? e.message : e.toString().replaceFirst('Exception: ', '');
                            if (dialogCtx.mounted) {
                              AppToast.error(dialogCtx, msg);
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsSheet(BuildContext context, OrderModel order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Store Name & Order Code
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName ?? 'pharmaCustomer Express Pharmacy',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${order.orderId} • ${_formatDateTime(order.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusBgColor(order.status),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusTextColor(order.status).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status.displayTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusTextColor(order.status),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Detailed Timeline Stepper
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineBorder),
              ),
              child: OrderTimelineStepper(
                status: order.status,
                statusHistory: order.statusHistory,
                rejectionReason: order.rejectionReason,
                cancellationReason: order.cancellationReason,
              ),
            ),

            const SizedBox(height: 20),

            // Itemized Bill Section
            const Text(
              'ITEMS ORDERED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppTheme.mutedText,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineBorder),
              ),
              child: Column(
                children: [
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.medication_outlined, size: 16, color: AppTheme.primary),
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
                                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item.formattedTotal,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 20),
                  // Bill breakdown
                  _billRow('Items Total', '₹${(order.itemsTotalPaise / 100).toStringAsFixed(2)}'),
                  if (order.deliveryFeePaise > 0)
                    _billRow('Delivery Fee', '₹${(order.deliveryFeePaise / 100).toStringAsFixed(2)}')
                  else
                    _billRow('Delivery Fee', 'FREE', isSuccess: true),
                  if (order.discountPaise > 0)
                    _billRow('Discount', '-₹${(order.discountPaise / 100).toStringAsFixed(2)}', isSuccess: true),
                  if (order.taxPaise > 0)
                    _billRow('Taxes & Charges', '₹${(order.taxPaise / 100).toStringAsFixed(2)}'),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      Text(
                        order.formattedTotal,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Delivery Address Snapshot
            if (order.deliveryAddressText != null && order.deliveryAddressText!.isNotEmpty) ...[
              const Text(
                'DELIVERY ADDRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (order.contactName != null && order.contactName!.isNotEmpty)
                            Text(
                              order.contactName!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          Text(
                            order.deliveryAddressText!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                          ),
                          if (order.contactMobile != null && order.contactMobile!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Mobile: ${order.contactMobile}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons inside Modal
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.outlineBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TaxInvoice(
                            orderId: order.orderId,
                            totalPaid: order.totalPayablePaise / 100.0,
                            orderDate: order.createdAt,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Invoice'),
                  ),
                ),
                const SizedBox(width: 12),
                if (order.isActive)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => LiveTracking(orderId: order.orderId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.moped_rounded, size: 18),
                      label: const Text('Live Track'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _handleReorder(context, order);
                      },
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Reorder'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _billRow(String label, String value, {bool isSuccess = false}) {
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
              color: isSuccess ? const Color(0xFF16A34A) : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} at $h:$min';
  }

  static Color _statusBgColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.DELIVERED:
        return const Color(0xFFDCFCE7);
      case OrderStatus.CANCELLED:
      case OrderStatus.STORE_REJECTED:
      case OrderStatus.DELIVERY_FAILED:
        return const Color(0xFFFEE2E2);
      case OrderStatus.OUT_FOR_DELIVERY:
      case OrderStatus.DRIVER_ASSIGNED:
        return const Color(0xFFE0F2F1);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  static Color _statusTextColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.DELIVERED:
        return const Color(0xFF16A34A);
      case OrderStatus.CANCELLED:
      case OrderStatus.STORE_REJECTED:
      case OrderStatus.DELIVERY_FAILED:
        return Colors.red.shade700;
      case OrderStatus.OUT_FOR_DELIVERY:
      case OrderStatus.DRIVER_ASSIGNED:
        return AppTheme.primaryDark;
      default:
        return const Color(0xFFB45309);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final orders = ordersProvider.orders;

    // Filter orders by search & tab
    final filteredOrders = orders.where((o) {
      final matchesTab = switch (filter) {
        'Active' => o.isActive,
        'Delivered' => o.status == OrderStatus.DELIVERED,
        'Cancelled' => o.status == OrderStatus.CANCELLED || o.status == OrderStatus.STORE_REJECTED,
        _ => true,
      };
      if (!matchesTab) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final matchesCode = o.orderId.toLowerCase().contains(q);
      final matchesItems = o.items.any((item) => item.name.toLowerCase().contains(q));
      final matchesStore = o.storeName?.toLowerCase().contains(q) ?? false;
      return matchesCode || matchesItems || matchesStore;
    }).toList();

    final activeOrders = filteredOrders.where((o) => o.isActive).toList();
    final pastOrders = filteredOrders.where((o) => !o.isActive).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRealtimeTimer();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern off-white background
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Your Orders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: AppTheme.primary),
            tooltip: '24x7 Help & Support',
            onPressed: () => showCustomerSupportSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ordersProvider.refresh(),
        child: orders.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
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
                              'When you place medicines or health orders, they will appear here with live tracking, refills and tax invoices.',
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  // Clean Search Bar
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      hintText: 'Search medicines, order ID or store...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.mutedText),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pill Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Active', 'Delivered', 'Cancelled']
                          .map(
                            (value) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(value),
                                selected: filter == value,
                                onSelected: (_) => setState(() => filter = value),
                                backgroundColor: Colors.white,
                                selectedColor: AppTheme.primary,
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: filter == value ? Colors.white : AppTheme.textSecondary,
                                ),
                                side: BorderSide(
                                  color: filter == value ? AppTheme.primary : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (filteredOrders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No orders match "$filter"',
                          style: const TextStyle(color: AppTheme.mutedText),
                        ),
                      ),
                    )
                  else ...[
                    // ── 1. ACTIVE ORDERS SECTION (PINNED PROMINENT CARDS) ──
                    if (activeOrders.isNotEmpty && (filter == 'All' || filter == 'Active')) ...[
                      Row(
                        children: [
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
                            'ACTIVE ORDERS (${activeOrders.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...activeOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ActiveOrderCard(
                            order: order,
                            onTap: () => _showOrderDetailsSheet(context, order),
                            onCancel: order.canCancel ? () => _showCancelOrderDialog(context, order) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── 2. PAST ORDERS ARCHIVE ──
                    if (pastOrders.isNotEmpty && (filter == 'All' || filter == 'Delivered' || filter == 'Cancelled')) ...[
                      if (activeOrders.isNotEmpty && filter == 'All') ...[
                        const Text(
                          'PAST ORDERS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: AppTheme.mutedText,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ...pastOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PastOrderCard(
                            order: order,
                            onTap: () => _showOrderDetailsSheet(context, order),
                            onReorder: () => _handleReorder(context, order),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// ── Blinkit-Style Active Order Card (High prominence, live map action) ──
class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const _ActiveOrderCard({
    required this.order,
    required this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _OrderHistoryState._statusTextColor(order.status);
    final statusBgColor = _OrderHistoryState._statusBgColor(order.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Store & Status Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.storeName ?? 'pharmaCustomer Express',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '#${order.orderId}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.displayTitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Doorstep Delivery OTP (If Out for Delivery)
            if (order.deliveryOtp != null && order.status.showDeliveryOtp) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Doorstep Delivery OTP: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                    ),
                    Text(
                      order.deliveryOtp!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Medicines Summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.take(2).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• ${item.name} × ${item.quantity}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      )),
                  if (order.items.length > 2)
                    Text(
                      '+ ${order.items.length - 2} more medicines',
                      style: const TextStyle(fontSize: 11, color: AppTheme.mutedText, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Footer: Total & Track Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Bill', style: TextStyle(fontSize: 10, color: AppTheme.mutedText)),
                      Text(
                        order.formattedTotal,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (onCancel != null) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onCancel,
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LiveTracking(orderId: order.orderId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.moped_rounded, size: 16),
                    label: const Text('Track Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Blinkit-Style Past Order Card (Clean, Reorder focused) ──
class _PastOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onReorder;

  const _PastOrderCard({
    required this.order,
    required this.onTap,
    required this.onReorder,
  });

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status == OrderStatus.DELIVERED;
    final statusColor = _OrderHistoryState._statusTextColor(order.status);
    final statusBgColor = _OrderHistoryState._statusBgColor(order.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Store Name + Status Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_outlined, size: 16, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.storeName ?? 'pharmaCustomer Pharmacy',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '#${order.orderId} • ${_formatDate(order.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.displayTitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Items Summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.take(2).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${item.name} × ${item.quantity}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      )),
                  if (order.items.length > 2)
                    Text(
                      '+ ${order.items.length - 2} more items',
                      style: const TextStyle(fontSize: 11, color: AppTheme.mutedText, fontStyle: FontStyle.italic),
                    ),
                  if (order.rejectionReason != null && order.rejectionReason!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Reason: ${order.rejectionReason}',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      ),
                    ),
                  if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Reason: ${order.cancellationReason}',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Bottom Actions Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Text(
                    order.formattedTotal,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TaxInvoice(
                            orderId: order.orderId,
                            totalPaid: order.totalPayablePaise / 100.0,
                            orderDate: order.createdAt,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 14, color: AppTheme.text),
                    label: const Text('Invoice', style: TextStyle(fontSize: 11, color: AppTheme.text)),
                  ),
                  const SizedBox(width: 8),
                  if (isDelivered)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onReorder,
                      icon: const Icon(Icons.replay_rounded, size: 14),
                      label: const Text('Reorder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showCustomerSupportSheet(context, orderId: order.orderId),
                      icon: const Icon(Icons.support_agent_rounded, size: 14, color: AppTheme.primary),
                      label: const Text('Help', style: TextStyle(fontSize: 11, color: AppTheme.primaryDark)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
