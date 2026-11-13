import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/theme.dart';
import 'coupon_offers.dart';
import 'order_review.dart';

class Payment extends StatefulWidget {
  const Payment({super.key});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  String method = 'UPI';
  String? upiApp;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final payable = cart.totalPrice;
    final hasCoupon = cart.couponCode != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Payment Options'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          if (cart.isLocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '15-Minute Inventory Hold Active',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Items reserved for ${cart.remainingHoldFormatted} to prevent stockout.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cart.remainingHoldFormatted,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: AppTheme.surfaceLow, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.verified_outlined, color: AppTheme.primary, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasCoupon
                            ? 'Coupon \'${cart.couponCode}\' applied · Saved ₹${(cart.discountPaise / 100).toStringAsFixed(0)}'
                            : 'subsidy applied · You save ₹161',
                        style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 28),
                const Text(
                  'TO PAY',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText, letterSpacing: .5),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cart.remoteCart?.formattedTotalPayable ?? '₹${payable.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _showCoupon,
                      child: Text(
                        hasCoupon ? 'Coupon applied ✓' : 'Coupons & Offers',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Row(children: [
            Icon(Icons.bolt, color: AppTheme.deliveryYellow, size: 22),
            SizedBox(width: 8),
            Text('Recommended · Fastest', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
          ),
          const SizedBox(height: 10),
          _panel(
            Column(
              children: [
                const Align(alignment: Alignment.centerLeft, child: Text('Pay with UPI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['GPay', 'PhonePe', 'Paytm', 'CRED']
                      .map(
                        (name) => ChoiceChip(
                          label: Text(name),
                          selected: upiApp == name,
                          onSelected: (_) => setState(() {
                            upiApp = name;
                            method = 'UPI';
                          }),
                          backgroundColor: AppTheme.mutedBg,
                          selectedColor: AppTheme.primaryContainer,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: upiApp == name
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          side: BorderSide(
                            color: upiApp == name
                                ? AppTheme.primary
                                : AppTheme.outlineBorder,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  onTap: () => setState(() => method = 'UPI'),
                  decoration: const InputDecoration(
                    hintText: 'Enter direct UPI ID / VPA',
                    suffixIcon: Icon(Icons.alternate_email),
                  ),
                  onChanged: (_) => setState(() => method = 'UPI'),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const Align(alignment: Alignment.centerLeft, child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text('Other payment methods', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                )),
                RadioGroup<String>(
                  groupValue: method,
                  onChanged: (value) => setState(() => method = value!),
                  child: Column(
                    children: [
                      _methodTile(
                        'Credit / Debit Card',
                        Icons.credit_card,
                        'Saved securely for quick checkout',
                        'Card',
                      ),
                      _methodTile(
                        'Net Banking',
                        Icons.account_balance,
                        'Choose from major Indian banks',
                        'Net Banking',
                      ),
                      _methodTile(
                        'Cash / QR on Delivery',
                        Icons.payments_outlined,
                        'Pay at your doorstep',
                        'COD',
                      ),
                    ],
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
                builder: (_) => OrderReview(amount: payable, method: method),
              ),
            ),
            icon: const Icon(Icons.lock_outline),
            label: Text('Continue · ₹${payable.toStringAsFixed(0)}'),
          ),
        ),
      ),
    );
  }

  Widget _methodTile(
    String title,
    IconData icon,
    String subtitle,
    String value,
  ) => RadioListTile<String>(
    contentPadding: EdgeInsets.zero,
    value: value,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    secondary: Icon(icon, color: AppTheme.primary),
  );

  void _showCoupon() {
    final cart = context.read<CartNotifier>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CouponOffers(
        applied: cart.couponCode != null,
        onApply: (code) {},
      ),
    );
  }
}

Widget _panel(Widget child) => Material(
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: const BorderSide(color: AppTheme.outlineBorder),
  ),
  clipBehavior: Clip.antiAlias,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);
