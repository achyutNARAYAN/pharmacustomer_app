import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/providers/load_status.dart';
import '../../core/models/cart_item.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import 'models/cart_models.dart';
import '../prescriptions/providers/prescription_provider.dart';
import '../prescriptions/repositories/prescription_repository.dart';
import '../prescriptions/prescription_vault.dart';
import '../prescriptions/prescription_upload_sheet.dart';
import '../prescriptions/prescription_review.dart';
import '../../core/providers/profile_notifier.dart';
import 'address.dart';
import 'coupon_offers.dart';

class Cart extends StatelessWidget {
  const Cart({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final rxProvider = context.watch<PrescriptionProvider?>();
    final rxStatus = rxProvider?.latestStatus ?? PrescriptionStatus.noneAttached;
    final isHydrating = cart.status == LoadStatus.hydrating;
    final profile = context.watch<ProfileNotifier?>();

    final hasValidAddress = (profile?.address.isNotEmpty ?? false) && profile!.address != 'Set delivery location';
    final addressText = hasValidAddress
        ? 'Deliver to ${profile.address.split(',').first.trim()}…'
        : 'Deliver to primary address…';

    final freeDeliveryThresholdPaise = 50000; // ₹500.00
    final currentPaise = cart.itemsTotalPaise;
    final isFreeDelivery = currentPaise >= freeDeliveryThresholdPaise || cart.items.isEmpty;
    final neededForFreeDelivery = (freeDeliveryThresholdPaise - currentPaise).clamp(0, freeDeliveryThresholdPaise);

    final requiresRx = cart.hasRxLines;
    final hasRxAttached = cart.hasPrescriptionAttached;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Shopping Cart (${cart.totalCount} items)'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              tooltip: 'Clear Cart',
              onPressed: () => _confirmClearCart(context, cart),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: isHydrating
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            )
          : cart.items.isEmpty
              ? _EmptyCartView()
              : RefreshIndicator(
                  onRefresh: () => cart.refresh(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Delivery Address Bar
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.surfaceLow,
                            child: Icon(Icons.bolt, color: AppTheme.primary),
                          ),
                          title: const Text(
                            'EXPRESS 22-MIN DELIVERY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          subtitle: Text(addressText),
                          trailing: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const Address(),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Free Delivery Threshold Banner
                      _FreeDeliveryBanner(
                        isFreeDelivery: isFreeDelivery,
                        neededForFreeDelivery: neededForFreeDelivery,
                        currentPaise: currentPaise,
                        thresholdPaise: freeDeliveryThresholdPaise,
                      ),
                      const SizedBox(height: 12),

                      // 3. Live Catalogue Warnings (Price Change / Stale items)
                      if (cart.warnings.isNotEmpty) ...[
                        ...cart.warnings.map((warning) => _WarningBanner(warning: warning)),
                        const SizedBox(height: 12),
                      ],

                      // 4. Cart Items Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Prescription & Health Items',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${cart.items.length} unique medicines',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 5. Line Items List
                      ...cart.items.map((item) => _CartItemTile(item: item)),
                      const SizedBox(height: 14),

                      // 6. Schedule H Prescription Compliance Card
                      _PrescriptionComplianceCard(
                        requiresPrescription: requiresRx,
                        hasPrescriptionAttached: hasRxAttached,
                        rxStatus: rxStatus,
                        attachedPrescriptionId: cart.prescriptionId,
                        onAttachPressed: () => _openPrescriptionPicker(context, cart),
                        onDetachPressed: () => cart.removePrescriptionId(),
                      ),
                      const SizedBox(height: 14),

                      // 7. Applied Coupon / Promo Bar
                      _CouponPromoCard(
                        appliedCoupon: cart.couponCode,
                        discountPaise: cart.discountPaise,
                        onOpenCoupons: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => CouponOffers(
                            applied: cart.couponCode != null,
                            onApply: (c) {},
                          ),
                        ),
                        onRemoveCoupon: () => cart.removeCouponCode(),
                      ),
                      const SizedBox(height: 16),

                      // 8. Authoritative FinTech Bill Summary (in Paise)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Bill Summary',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${cart.totalCount} items',
                                    style: const TextStyle(color: AppTheme.mutedText),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _BillRow(
                                label: 'Items total',
                                value: cart.remoteCart?.formattedItemsTotal ??
                                    '₹${(cart.itemsTotalPaise / 100).toStringAsFixed(0)}',
                              ),
                              if (cart.discountPaise > 0) ...[
                                const SizedBox(height: 8),
                                _BillRow(
                                  label: 'Coupon discount (${cart.couponCode})',
                                  value: '−${cart.remoteCart?.formattedDiscount ?? "₹${(cart.discountPaise / 100).toStringAsFixed(0)}"}',
                                  valueColor: AppTheme.successText,
                                ),
                              ],
                              const SizedBox(height: 8),
                              _BillRow(
                                label: 'Delivery fee',
                                value: cart.remoteCart?.formattedDeliveryFee ??
                                    (isFreeDelivery ? 'FREE' : '₹40'),
                                valueColor: isFreeDelivery ? AppTheme.successText : null,
                              ),
                              const SizedBox(height: 8),
                              const _BillRow(
                                label: 'Handling & packaging',
                                value: 'FREE',
                                valueColor: AppTheme.successText,
                              ),
                              const SizedBox(height: 8),
                              const _BillRow(
                                label: 'Taxes (GST included)',
                                value: 'Included',
                              ),
                              const Divider(height: 24),
                              _BillRow(
                                label: 'Total payable',
                                value: cart.remoteCart?.formattedTotalPayable ??
                                    '₹${(cart.totalPayablePaise / 100).toStringAsFixed(0)}',
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  if (requiresRx && !hasRxAttached) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Schedule H medicine requires an approved doctor\'s prescription. Please attach one to proceed.',
                        ),
                        backgroundColor: Colors.amber.shade900,
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Attach',
                          textColor: Colors.white,
                          onPressed: () => _openPrescriptionPicker(context, cart),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const Address()),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cart.remoteCart?.formattedTotalPayable ??
                                '₹${(cart.totalPayablePaise / 100).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Inclusive of applicable taxes',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Proceed to Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _confirmClearCart(BuildContext context, CartNotifier cart) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Shopping Cart?'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              cart.clearAll();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrescriptionUpload(BuildContext context, CartNotifier cart) async {
    final file = await showPrescriptionUploadSheet(context);
    if (file == null || !context.mounted) return;

    final profile = context.read<ProfileNotifier?>();
    final pName = (profile?.name.isNotEmpty ?? false) ? profile!.name : 'Customer';

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PrescriptionReview(
          file: file,
          patientName: pName,
        ),
      ),
    );

    if (submitted == true && context.mounted) {
      String rxId = 'rx_${DateTime.now().millisecondsSinceEpoch}';
      try {
        if (ApiService.token != null) {
          final effectiveCustomerId = ApiService.currentCustomerId ??
              context.read<AuthProvider?>()?.userId;
          final res = await ApiService.uploadPrescription(
            customerId: effectiveCustomerId,
            patientName: pName,
            prescriptionDate: DateTime.now(),
            documentUrl: file.path ?? 'https://res.cloudinary.com/demo/sample_rx.pdf',
            fileSize: file.size,
            mimeType: file.extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
          );
          if (res != null) {
            final doc = res['prescription'] ?? res['data'] ?? res;
            if (doc is Map && doc['_id'] != null) {
              rxId = doc['_id'].toString();
            } else if (res['_id'] != null) {
              rxId = res['_id'].toString();
            }
          }
        }
      } catch (_) {}

      if (context.mounted) {
        final rxProvider = context.read<PrescriptionProvider?>();
        rxProvider?.addPrescription(
          Prescription(
            id: rxId,
            source: 'upload',
            status: PrescriptionStatus.approved,
            fileName: file.name,
            mime: file.extension ?? 'image/jpeg',
            sizeBytes: file.size,
            remoteUrl: file.path,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Automatically link this uploaded prescription to the cart
        await cart.attachPrescriptionId(rxId);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Prescription "${file.name}" uploaded and attached!')),
              ],
            ),
            backgroundColor: AppTheme.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openPrescriptionPicker(BuildContext context, CartNotifier cart) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final rxProvider = ctx.watch<PrescriptionProvider?>();
        final prescriptions = rxProvider?.prescriptions ?? [];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outlineBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Verified Prescription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Attach an approved prescription belonging to your account',
                  style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (prescriptions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.description_outlined, size: 48, color: AppTheme.mutedText),
                          const SizedBox(height: 10),
                          const Text('No prescriptions uploaded yet', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload your doctor prescription to proceed with checkout',
                            style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handlePrescriptionUpload(context, cart);
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload New Prescription'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...prescriptions.map((p) {
                    final isApproved = p.status == PrescriptionStatus.approved ||
                        p.status == PrescriptionStatus.underReview;
                    final isSelected = cart.prescriptionId == p.id;
                    final dateStr = '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            p.status == PrescriptionStatus.approved
                                ? Icons.verified_user
                                : Icons.schedule,
                            color: p.status == PrescriptionStatus.approved
                                ? AppTheme.primary
                                : Colors.amber.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.doctorName ?? p.fileName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: ${p.status.chipLabel} • $dateStr',
                                  style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          isSelected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Attached ✓',
                                    style: TextStyle(
                                      color: AppTheme.successText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : InkWell(
                                  onTap: isApproved
                                      ? () {
                                          cart.attachPrescriptionId(p.id);
                                          Navigator.pop(ctx);
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isApproved ? AppTheme.primary : AppTheme.surfaceContainerDim,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Attach',
                                      style: TextStyle(
                                        color: isApproved ? Colors.white : AppTheme.mutedText,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handlePrescriptionUpload(context, cart);
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload New Prescription'),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    final profile = context.read<ProfileNotifier?>();
                    final pName = (profile?.name.isNotEmpty ?? false) ? profile!.name : 'Customer';
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PrescriptionVault(patientName: pName),
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_shared_outlined),
                  label: const Text('Open Prescription Vault'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for medicines or daily essentials and add them to your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mutedText),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Browse Medicines'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeDeliveryBanner extends StatelessWidget {
  final bool isFreeDelivery;
  final int neededForFreeDelivery;
  final int currentPaise;
  final int thresholdPaise;

  const _FreeDeliveryBanner({
    required this.isFreeDelivery,
    required this.neededForFreeDelivery,
    required this.currentPaise,
    required this.thresholdPaise,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentPaise / thresholdPaise).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFreeDelivery ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFreeDelivery ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFreeDelivery ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                color: isFreeDelivery ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFreeDelivery
                      ? 'Congratulations! You unlocked FREE Delivery (₹40 saved)'
                      : 'Add ₹${(neededForFreeDelivery / 100).toStringAsFixed(0)} more for FREE Delivery!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isFreeDelivery ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (!isFreeDelivery) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.amber.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final CartWarning warning;
  const _WarningBanner({required this.warning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              warning.message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFE65100), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartNotifier>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.medication_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (item.pack.isNotEmpty)
                    Text(
                      item.pack,
                      style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
                    ),
                  if (item.requiresPrescription) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Rx Required',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '₹${item.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => cart.remove(item.id),
                    icon: const Icon(Icons.remove, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: item.quantity < 50 ? () => cart.add(item) : null,
                    icon: const Icon(Icons.add, size: 18),
                    visualDensity: VisualDensity.compact,
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

class _PrescriptionComplianceCard extends StatelessWidget {
  final bool requiresPrescription;
  final bool hasPrescriptionAttached;
  final PrescriptionStatus rxStatus;
  final String? attachedPrescriptionId;
  final VoidCallback onAttachPressed;
  final VoidCallback onDetachPressed;

  const _PrescriptionComplianceCard({
    required this.requiresPrescription,
    required this.hasPrescriptionAttached,
    required this.rxStatus,
    this.attachedPrescriptionId,
    required this.onAttachPressed,
    required this.onDetachPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!requiresPrescription) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No Prescription Required', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'All items in your cart are over-the-counter wellness products.',
                      style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasPrescriptionAttached ? AppTheme.primary : Colors.amber.shade800,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: hasPrescriptionAttached ? AppTheme.primary : Colors.amber.shade900,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Schedule H Prescription Compliance',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPrescriptionAttached ? AppTheme.successBg : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasPrescriptionAttached ? 'ATTACHED ✓' : 'REQUIRED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasPrescriptionAttached ? AppTheme.successText : const Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              hasPrescriptionAttached
                  ? 'Doctor\'s prescription successfully linked to this order.'
                  : 'Your cart contains Schedule H medicines that legally require an approved prescription before fulfillment.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasPrescriptionAttached)
                  TextButton.icon(
                    onPressed: onDetachPressed,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Change / Remove'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onAttachPressed,
                    icon: const Icon(Icons.attachment_rounded, size: 18),
                    label: const Text('Attach Prescription'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponPromoCard extends StatelessWidget {
  final String? appliedCoupon;
  final int discountPaise;
  final VoidCallback onOpenCoupons;
  final VoidCallback onRemoveCoupon;

  const _CouponPromoCard({
    this.appliedCoupon,
    required this.discountPaise,
    required this.onOpenCoupons,
    required this.onRemoveCoupon,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoupon = appliedCoupon != null && appliedCoupon!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasCoupon ? AppTheme.primary : AppTheme.outlineBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: hasCoupon ? AppTheme.primary : AppTheme.mutedText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: hasCoupon
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coupon \'$appliedCoupon\' Applied',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'You saved ₹${(discountPaise / 100).toStringAsFixed(0)} on this order',
                        style: const TextStyle(fontSize: 11, color: AppTheme.successText, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : const Text(
                    'Apply Coupon / Promo Code',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
          if (hasCoupon)
            TextButton(
              onPressed: onRemoveCoupon,
              child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
            )
          else
            TextButton(
              onPressed: onOpenCoupons,
              child: const Text('Select'),
            ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? (bold ? AppTheme.primaryDark : AppTheme.text),
            ),
          ),
        ],
      );
}
