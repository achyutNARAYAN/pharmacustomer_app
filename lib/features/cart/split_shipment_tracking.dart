import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';

class SplitShipmentTracking extends StatelessWidget {
  const SplitShipmentTracking({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final profile = context.watch<ProfileNotifier>();
    final items = cart.items;
    final first = items.isNotEmpty ? items.first : null;
    final second = items.length > 1 ? items.skip(1).toList() : <dynamic>[];
    final addressDisplay = profile.address.isNotEmpty ? profile.address : 'Saved Delivery Address';
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        toolbarHeight: 72,
        title: const Column(
          children: [
            Text(
              'LIVE ORDER TRACKER',
              style: TextStyle(fontSize: 10, color: AppTheme.mutedText),
            ),
            Text('Track Order #AC-9941'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONSOLIDATED ORDER',
                  style: TextStyle(fontSize: 10, color: AppTheme.mutedText),
                ),
                Text(
                  '₹${cart.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 20),
                const Text(
                  '🚚  Multi-Store Delivery',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Your medicines are arriving in separate shipments from nearby licensed pharmacies.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _shipment(
            'Shipment 1 of 2',
            'Fulfillment Hub 01',
            'Licensed Pharmacy · Dispatch verified',
            'Out for delivery · ~10 mins',
            first?.name ?? 'Medicine order',
            first == null ? 0 : first.total,
            'Assigned Courier Partner · Delivery underway',
            true,
          ),
          const SizedBox(height: 16),
          _shipment(
            'Shipment 2 of 2',
            'Regional Dispensing Center',
            'Clinical sorting & quality verified',
            'Packing at pharmacy · ~30 mins',
            second.isEmpty
                ? 'Remaining medicines'
                : second.map((item) => item.name).join(', '),
            second.fold<double>(0, (sum, item) => sum + item.total),
            'Assigning nearby courier partner',
            false,
          ),
          const SizedBox(height: 16),
          _card(
            ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppTheme.primary,
              ),
              title: const Text('Delivery Address & Payment'),
              subtitle: Text(
                '$addressDisplay\nPrepaid Order · Digital invoice available',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _shipment(
  String title,
  String store,
  String detail,
  String status,
  String medicine,
  double price,
  String courier,
  bool active,
) => _card(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppTheme.successBg : AppTheme.warningBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: active ? AppTheme.successText : AppTheme.warningText)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.storefront_outlined, color: AppTheme.primary, size: 25)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(store, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: AppTheme.mutedText)),
          ])),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.medication_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(medicine, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(
              '₹${price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(active ? 'Delivery progress' : 'Preparation progress', style: const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
          const Spacer(),
          Text(active ? 'On the way' : 'In preparation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? AppTheme.primary : AppTheme.warningText)),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: active ? .75 : .35,
        color: active ? AppTheme.primary : AppTheme.warningText,
        backgroundColor: AppTheme.surfaceLow,
        minHeight: 6,
        borderRadius: BorderRadius.circular(8),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(Icons.person_pin_circle_outlined, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(courier, style: const TextStyle(fontSize: 13))),
          if (active)
            IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
        ],
      ),
    ],
  ),
);

Widget _card(Widget child) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: AppTheme.outlineBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
    ],
  ),
  child: child,
);
