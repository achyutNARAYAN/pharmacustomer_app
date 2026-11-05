import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/utils/pincode_validator.dart';
import '../profile/providers/customer_address_provider.dart';
import 'address.dart';
import 'payment_processing.dart';

class OrderReview extends StatelessWidget {
  const OrderReview({super.key, required this.amount, required this.method});
  final double amount;
  final String method;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final profile = context.watch<ProfileNotifier>();

    CustomerAddressProvider? addressProvider;
    try {
      addressProvider = Provider.of<CustomerAddressProvider>(context);
    } catch (_) {}

    final activeAddress = addressProvider?.selectedAddress ?? addressProvider?.defaultAddress;
    final customerName = activeAddress?.contactName ??
        (profile.name.isNotEmpty ? profile.name : 'Customer');
    final deliveryAddress = activeAddress != null
        ? activeAddress.displayDetails
        : (profile.address.isNotEmpty
            ? profile.address
            : 'Primary Delivery Location');
    final addressTypeLabel = activeAddress?.typeKey ?? 'Home';

    final pinCode = activeAddress?.pinCode ??
        RegExp(r'\b[1-9][0-9]{5}\b').firstMatch(deliveryAddress)?.group(0);
    final isServiceable = activeAddress != null
        ? activeAddress.isServiceable
        : (pinCode != null ? PincodeValidator.isServiceable(pinCode) : true);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Review & Confirm Order'),
          Text('Express Checkout', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _iconBox(Icons.local_shipping_outlined),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text('Express Delivery Slot', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isServiceable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isServiceable ? 'Serviceable' : 'Unserviceable PIN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isServiceable ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('$addressTypeLabel · $customerName', style: const TextStyle(color: AppTheme.mutedText)),
            const SizedBox(height: 3),
            Text(deliveryAddress, style: const TextStyle(color: AppTheme.mutedText, height: 1.35)),
          ])),
          const SizedBox(width: 8),
          const Text('22 min', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const Address()),
            ),
            child: const Text('Change'),
          ),
        ])),
        if (!isServiceable) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PIN code ${pinCode ?? ""} is currently unserviceable for delivery. Order placement is restricted.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Medicines · ${cart.totalCount} items', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const Divider(height: 26),
          ...cart.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _iconBox(Icons.medication_outlined, small: true),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${item.pack} · ${item.quantity} unit(s)', style: const TextStyle(color: AppTheme.mutedText)),
              ])),
              const SizedBox(width: 8),
              Text('₹${item.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          )),
          const Divider(),
          _row('Items total', '₹${cart.totalPrice.toStringAsFixed(0)}'),
          _row('Prescription subsidy & discount', '−₹${(cart.totalPrice - amount).toStringAsFixed(0)}', green: true),
          _row('Express delivery', 'FREE', green: true),
          const Divider(height: 24),
          _row('Total payable', '₹${amount.toStringAsFixed(0)}', bold: true),
        ])),
        const SizedBox(height: 16),
        _card(Row(children: [
          _iconBox(Icons.account_balance_wallet_outlined),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 3),
            Text(method, style: const TextStyle(color: AppTheme.mutedText)),
          ])),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Change')),
        ])),
        const SizedBox(height: 18),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.mutedText),
          SizedBox(width: 8),
          Expanded(child: Text('By authorizing, you confirm this order and agree to the pharmacy dispensing terms.', style: TextStyle(color: AppTheme.mutedText, height: 1.4))),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: ElevatedButton.icon(
            onPressed: () async {
              if (!isServiceable) {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Unserviceable Address'),
                      ],
                    ),
                    content: Text(
                      'Delivery is not available at PIN code ${pinCode ?? "selected"}. '
                      'Our dark store network does not service this location yet. '
                      'Please select or add a serviceable delivery address to place your order.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const Address(),
                            ),
                          );
                        },
                        child: const Text('Change Address'),
                      ),
                    ],
                  ),
                );
                return;
              }

              try {
                if (ApiService.token != null) {
                  final addrId = activeAddress?.id.isNotEmpty == true
                      ? activeAddress!.id
                      : 'addr_default';
                  await ApiService.checkout(
                    addressId: addrId,
                    prescriptionId: cart.hasPrescriptionAttached ? 'RX-CURRENT' : null,
                  );
                }
              } catch (_) {}
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PaymentProcessing(amount: amount),
                ),
              );
            },
            icon: Icon(isServiceable ? Icons.verified_user_outlined : Icons.lock_outline_rounded),
            label: Text(
              isServiceable
                  ? 'Authorize & Pay  ·  ₹${amount.toStringAsFixed(0)}'
                  : 'Address Unserviceable',
            ),
            style: isServiceable
                ? null
                : ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600),
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
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: green ? AppTheme.successText : (bold ? AppTheme.primaryDark : AppTheme.text))),
  ]),
);
