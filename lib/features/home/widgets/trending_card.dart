import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/theme.dart';

class TrendingCard extends StatelessWidget {
  final String? id;
  final String title;
  final String subtitle;
  final String price;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;

  const TrendingCard({
    super.key,
    this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
  });

  double get _parsedPrice {
    final cleaned = price.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String get _cartId => id ?? title.toLowerCase().replaceAll(' ', '_');

  @override
  Widget build(BuildContext context) {
    final qty = context.watch<CartNotifier>().quantityOf(_cartId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineBorder),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImagePlaceholder(tag: tag, tagColor: tagColor, tagTextColor: tagTextColor),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.text)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text)),
              if (qty == 0)
                ElevatedButton(
                  onPressed: () => context.read<CartNotifier>().add(
                        CartItem(id: _cartId, name: title, pack: subtitle, price: _parsedPrice),
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('+ Add', style: TextStyle(fontSize: 12)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 14, color: AppTheme.primary),
                        onPressed: () => context.read<CartNotifier>().remove(_cartId),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Text('$qty',
                            key: ValueKey(qty),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 14, color: AppTheme.primary),
                        onPressed: () => context.read<CartNotifier>().add(
                              CartItem(id: _cartId, name: title, pack: subtitle, price: _parsedPrice),
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  const _ImagePlaceholder({required this.tag, required this.tagColor, required this.tagTextColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFF5F8F9), borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          Center(child: Icon(Icons.medication, size: 48, color: Colors.grey.shade400)),
          Positioned(
            top: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(4)),
              child: Text(tag,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagTextColor)),
            ),
          ),
        ],
      ),
    );
  }
}
