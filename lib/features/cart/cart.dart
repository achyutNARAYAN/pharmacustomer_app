import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/providers/load_status.dart';
import '../../core/models/cart_item.dart';
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

    final approvedPrescriptions = rxProvider?.prescriptions
            .where((p) => p.status == PrescriptionStatus.approved)
            .toList() ??
        [];

    // Auto-attach latest approved prescription if cart requires Rx, none is attached yet,
    // and customer has not explicitly detached it in this session.
    if (requiresRx &&
        !hasRxAttached &&
        !cart.userExplicitlyDetachedRx &&
        approvedPrescriptions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!cart.hasPrescriptionAttached && !cart.userExplicitlyDetachedRx && context.mounted) {
          cart.attachPrescriptionId(approvedPrescriptions.first.id);
        }
      });
    }

    String? attachedRxName;
    if (cart.prescriptionId != null && rxProvider != null) {
      for (final p in rxProvider.prescriptions) {
        if (p.id == cart.prescriptionId) {
          attachedRxName = p.doctorName ?? p.fileName;
          break;
        }
      }
    }

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
                        attachedPrescriptionName: attachedRxName,
                        onAttachPressed: () => _openPrescriptionPicker(context, cart),
                        onChangePressed: () => _openPrescriptionPicker(context, cart),
                        onRemovePressed: () async {
                          await cart.removePrescriptionId();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Prescription detached from order'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
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

    final uploadedRx = await Navigator.of(context).push<Prescription?>(
      MaterialPageRoute<Prescription?>(
        builder: (_) => PrescriptionReview(
          file: file,
          patientName: pName,
        ),
      ),
    );

    if (uploadedRx != null && context.mounted) {
      // Automatically link this verified uploaded prescription to the cart
      await cart.attachPrescriptionId(uploadedRx.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Prescription "${uploadedRx.fileName}" uploaded and attached!')),
            ],
          ),
          backgroundColor: AppTheme.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openPrescriptionPicker(BuildContext context, CartNotifier cart) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final rxProvider = ctx.watch<PrescriptionProvider?>();
        final rawPrescriptions = rxProvider?.prescriptions ?? [];
        final prescriptions = List<Prescription>.from(rawPrescriptions)
          ..sort((a, b) {
            final aSelected = cart.prescriptionId == a.id;
            final bSelected = cart.prescriptionId == b.id;
            if (aSelected && !bSelected) return -1;
            if (!aSelected && bSelected) return 1;

            final aApproved = a.status == PrescriptionStatus.approved;
            final bApproved = b.status == PrescriptionStatus.approved;
            if (aApproved && !bApproved) return -1;
            if (!aApproved && bApproved) return 1;

            final aReview = a.status == PrescriptionStatus.underReview;
            final bReview = b.status == PrescriptionStatus.underReview;
            if (aReview && !bReview) return -1;
            if (!aReview && bReview) return 1;

            return b.createdAt.compareTo(a.createdAt);
          });

        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Handle & Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
                    child: Column(
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Verified Prescription',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.text,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Attach an approved prescription belonging to your account',
                                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, color: AppTheme.mutedText),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable Prescription Items
                  Expanded(
                    child: prescriptions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.description_outlined, size: 48, color: AppTheme.mutedText),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No prescriptions uploaded yet',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Upload your doctor prescription to proceed with checkout',
                                    style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: prescriptions.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = prescriptions[index];
                              final isApproved = p.status == PrescriptionStatus.approved;
                              final isUnderReview = p.status == PrescriptionStatus.underReview;
                              final isSelected = cart.prescriptionId == p.id;
                              final dateStr = '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      isApproved
                                          ? Icons.verified_user
                                          : isUnderReview
                                              ? Icons.schedule
                                              : Icons.error_outline,
                                      color: isApproved
                                          ? AppTheme.primary
                                          : isUnderReview
                                              ? Colors.amber.shade800
                                              : AppTheme.mutedText,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            (p.doctorName != null && p.doctorName!.trim().isNotEmpty)
                                                ? p.doctorName!.trim()
                                                : (p.fileName.contains('invoice_') || p.fileName.contains('customerId'))
                                                    ? 'Prescription #${p.id.length > 8 ? p.id.substring(0, 8) : p.id}'
                                                    : p.fileName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isApproved
                                                ? 'Status: Verified & Approved • $dateStr'
                                                : isUnderReview
                                                    ? 'Status: Under review (Pharmacist checking) • $dateStr'
                                                    : 'Status: ${p.status.chipLabel} • $dateStr',
                                            style: TextStyle(
                                              color: isApproved ? AppTheme.primary : AppTheme.mutedText,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isSelected)
                                      Container(
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
                                    else if (isApproved)
                                      InkWell(
                                        onTap: () async {
                                          final success = await cart.attachPrescriptionId(p.id);
                                          if (!ctx.mounted) return;
                                          Navigator.pop(ctx);
                                          if (success && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text('Prescription "${p.doctorName ?? p.fileName}" attached to cart!'),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: AppTheme.primaryDark,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Attach',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceContainerDim,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isUnderReview ? 'In Review' : 'Unavailable',
                                          style: const TextStyle(
                                            color: AppTheme.mutedText,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action Buttons (Never Overflows!)
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handlePrescriptionUpload(context, cart);
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload New Prescription'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
  final String? attachedPrescriptionName;
  final VoidCallback onAttachPressed;
  final VoidCallback onChangePressed;
  final VoidCallback onRemovePressed;

  const _PrescriptionComplianceCard({
    required this.requiresPrescription,
    required this.hasPrescriptionAttached,
    required this.rxStatus,
    this.attachedPrescriptionId,
    this.attachedPrescriptionName,
    required this.onAttachPressed,
    required this.onChangePressed,
    required this.onRemovePressed,
  });

  String _cleanRxDisplayName() {
    final rawName = attachedPrescriptionName?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      if (rawName.startsWith('Dr.') || rawName.startsWith('dr.')) {
        return rawName;
      }
      if (rawName.contains('invoice_') || rawName.contains('customerId')) {
        final match = RegExp(r'invoice_([A-Za-z0-9]{4,10})').firstMatch(rawName);
        if (match != null) {
          return 'Prescription #${match.group(1)}';
        }
        return 'Digital Rx Document';
      }
      if (rawName.length > 24) {
        final ext = rawName.contains('.') ? '.${rawName.split('.').last}' : '';
        return 'Prescription_${rawName.substring(0, 8)}$ext';
      }
      return rawName;
    }
    if (attachedPrescriptionId != null && attachedPrescriptionId!.trim().isNotEmpty) {
      final id = attachedPrescriptionId!.trim();
      return 'Prescription #${id.length > 8 ? id.substring(0, 8) : id}';
    }
    return 'Verified Clinical Rx';
  }

  @override
  Widget build(BuildContext context) {
    if (!requiresPrescription) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineBorder.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.successText, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Prescription Required',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.text),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All items in your cart are over-the-counter wellness products.',
                    style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (hasPrescriptionAttached) {
      final displayTitle = _cleanRxDisplayName();

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC7EBE3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Shield Badge + Title + VERIFIED pill
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prescription Attached',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.text,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Schedule H Compliance Verified',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: AppTheme.successText, size: 12),
                        SizedBox(width: 3),
                        Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.successText,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Embedded Credential Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.description_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Active for this order • Verified Rx',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Elegant "Change" pill
                    InkWell(
                      onTap: onChangePressed,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBCE3ED)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 14, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Bottom Micro-Footer: Registered Pharmacist note + Discrete Remove
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 13, color: AppTheme.mutedText),
                      SizedBox(width: 4),
                      Text(
                        'Dispensed after pharmacist review',
                        style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onRemovePressed,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Prescription REQUIRED state
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD8A8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFD97706), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prescription Required',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.text,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Schedule H Regulated Medicine',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your cart contains medicines that legally require an approved doctor\'s prescription before dispatch.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAttachPressed,
                icon: const Icon(Icons.attachment_rounded, size: 18),
                label: const Text(
                  'Attach Prescription',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
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
