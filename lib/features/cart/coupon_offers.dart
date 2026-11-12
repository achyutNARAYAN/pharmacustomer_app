import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/theme.dart';

class CouponOffers extends StatefulWidget {
  const CouponOffers({super.key, required this.onApply, required this.applied});
  final ValueChanged<String> onApply;
  final bool applied;

  @override
  State<CouponOffers> createState() => _CouponOffersState();
}

class _CouponOffersState extends State<CouponOffers> {
  final controller = TextEditingController();
  bool _isApplying = false;
  String? _errorMessage;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleApply(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    final cart = context.read<CartNotifier>();
    final success = await cart.applyCouponCode(trimmed);

    if (!mounted) return;
    setState(() {
      _isApplying = false;
    });

    if (success) {
      widget.onApply(trimmed);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coupon \'$trimmed\' applied successfully!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = cart.actionError ?? 'Unable to apply coupon. Please check minimum order value.';
      });
    }
  }

  Future<void> _handleRemove() async {
    final cart = context.read<CartNotifier>();
    await cart.removeCouponCode();
    widget.onApply('');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final itemsTotalPaise = cart.itemsTotalPaise;
    final currentCoupon = cart.couponCode;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineBorder,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Coupons & Offers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Maximize savings on your prescribed healthcare',
              style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter coupon code (e.g. WELCOME50)',
                suffixIcon: _isApplying
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: () => _handleApply(controller.text),
                        child: const Text('Apply'),
                      ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Available MVP Coupons',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // Coupon 1: WELCOME50
            _CouponCard(
              code: 'WELCOME50',
              title: 'Flat ₹50 OFF',
              description: 'Flat ₹50 discount on minimum order of ₹200 (20,000 paise).',
              minOrderPaise: 20000,
              currentTotalPaise: itemsTotalPaise,
              isApplied: currentCoupon == 'WELCOME50',
              onApply: () => _handleApply('WELCOME50'),
            ),
            const SizedBox(height: 10),

            // Coupon 2: SAVE10
            _CouponCard(
              code: 'SAVE10',
              title: '10% OFF up to ₹100',
              description: '10% discount up to ₹100 on minimum order of ₹300 (30,000 paise).',
              minOrderPaise: 30000,
              currentTotalPaise: itemsTotalPaise,
              isApplied: currentCoupon == 'SAVE10',
              onApply: () => _handleApply('SAVE10'),
            ),

            if (widget.applied || currentCoupon != null) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _handleRemove,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                  label: const Text('Remove applied coupon', style: TextStyle(color: AppTheme.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final String code;
  final String title;
  final String description;
  final int minOrderPaise;
  final int currentTotalPaise;
  final bool isApplied;
  final VoidCallback onApply;

  const _CouponCard({
    required this.code,
    required this.title,
    required this.description,
    required this.minOrderPaise,
    required this.currentTotalPaise,
    required this.isApplied,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final isEligible = currentTotalPaise >= minOrderPaise;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isApplied ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApplied
              ? AppTheme.primary
              : (isEligible ? AppTheme.outlineBorder : Colors.grey.shade300),
          width: isApplied ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_offer_outlined, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      code,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                ),
                if (!isEligible) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Add ₹${((minOrderPaise - currentTotalPaise) / 100).toStringAsFixed(0)} more to unlock',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isApplied)
            const Chip(
              label: Text('Applied ✓', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            )
          else
            TextButton(
              onPressed: isEligible ? onApply : null,
              child: const Text('Apply'),
            ),
        ],
      ),
    );
  }
}
