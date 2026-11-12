import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/theme.dart';

class MedicineListCard extends StatelessWidget {
  final String? id;
  final String name;
  final String description;
  final String price;
  final String mrp;
  final String discount;
  final String badge;
  final bool requiresPrescription;
  final String? tag;
  final String? deliveryNote;
  final VoidCallback? onTap;

  const MedicineListCard({
    super.key,
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.mrp,
    required this.discount,
    required this.badge,
    required this.requiresPrescription,
    this.tag,
    this.deliveryNote,
    this.onTap,
  });

  // Strip '₹' and commas to get a double for the cart
  double get _parsedPrice {
    final cleaned = price.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String get _cartId => id ?? name.toLowerCase().replaceAll(' ', '_');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineBorder.withValues(alpha: .8)),
          boxShadow: [BoxShadow(color: AppTheme.text.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const _MedicineIcon(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MedicineInfo(
                      badge: badge,
                      name: name,
                      description: description,
                      tag: tag,
                      requiresPrescription: requiresPrescription,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _PriceRow(price: price, mrp: mrp, discount: discount)),
                        const SizedBox(width: 10),
                        _CartControl(
                          cartId: _cartId,
                          name: name,
                          pack: tag ?? '',
                          price: _parsedPrice,
                          requiresPrescription: requiresPrescription,
                        ),
                      ],
                    ),
                    if (deliveryNote != null) ...[
                      const SizedBox(height: 6),
                      Text(deliveryNote!, style: const TextStyle(fontSize: 11, color: AppTheme.mutedText)),
                    ],
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cart control (Add / counter) ──────────────────────────────────────────────

class _CartControl extends StatelessWidget {
  final String cartId;
  final String name;
  final String pack;
  final double price;
  final bool requiresPrescription;

  const _CartControl({
    required this.cartId,
    required this.name,
    required this.pack,
    required this.price,
    this.requiresPrescription = false,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final qty = cart.quantityOf(cartId);

    if (qty == 0) {
      return ElevatedButton(
        onPressed: () => context.read<CartNotifier>().add(
              CartItem(
                id: cartId,
                name: name,
                pack: pack,
                price: price,
                requiresPrescription: requiresPrescription,
              ),
            ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(84, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: AppTheme.primary),
            onPressed: () => context.read<CartNotifier>().remove(cartId),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Text('$qty',
                key: ValueKey(qty),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
            onPressed: () => context.read<CartNotifier>().add(
                  CartItem(id: cartId, name: name, pack: pack, price: price),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _MedicineIcon extends StatelessWidget {
  const _MedicineIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      alignment: Alignment.center,
      color: AppTheme.primaryContainer,
      child: const Icon(Icons.medication_outlined, color: AppTheme.primary, size: 31),
    );
  }
}

class _MedicineInfo extends StatelessWidget {
  final String badge;
  final String name;
  final String description;
  final String? tag;
  final bool requiresPrescription;
  const _MedicineInfo({required this.badge, required this.name, required this.description, required this.requiresPrescription, this.tag});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tag ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.mutedText))),
            if (requiresPrescription)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.errorBg, borderRadius: BorderRadius.circular(7)),
                child: Text(badge, style: const TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.text)),
        const SizedBox(height: 2),
        Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11)),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String price;
  final String mrp;
  final String discount;
  const _PriceRow({required this.price, required this.mrp, required this.discount});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        Flexible(child: Text(price, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.text))),
        const SizedBox(width: 6),
        Text(discount, style: const TextStyle(color: AppTheme.successText, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
      const SizedBox(height: 3),
      Text(mrp, style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppTheme.mutedText, fontSize: 11)),
    ],
  );
}
