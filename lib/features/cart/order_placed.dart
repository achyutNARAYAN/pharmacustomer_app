import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';
import 'clinical_dispensing.dart';

class OrderPlaced extends StatelessWidget {
  const OrderPlaced({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final profile = context.watch<ProfileNotifier>();
    final deliveryAddress = profile.address.isNotEmpty
        ? profile.address
        : 'Primary Delivery Location';
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'ORDER CONFIRMED',
              style: TextStyle(fontSize: 10, color: AppTheme.mutedText),
            ),
            Text('Processing Order'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          _card(
            Column(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.surfaceLow,
                  child: Icon(
                    Icons.check_circle,
                    size: 36,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Payment Confirmed · Order placed successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '⚡ Estimated delivery in 22 mins · by 3:15 PM',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.primaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            const ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.surfaceLow,
                child: Icon(
                  Icons.local_pharmacy_outlined,
                  color: AppTheme.primary,
                ),
              ),
              title: Text(
                'FULFILLMENT PHARMACY',
                style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
              ),
              subtitle: Text(
                'Nearest Licensed Dispensary Hub',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: CircleAvatar(child: Icon(Icons.storefront_outlined, size: 18)),
            ),
          ),
          const SizedBox(height: 16),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cart.totalCount} Medicines Ordered',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 20),
                ...cart.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.medication_outlined,
                      color: AppTheme.primary,
                    ),
                    title: Text(item.name),
                    subtitle: Text(item.pack),
                    trailing: Text('₹${item.total.toStringAsFixed(0)}'),
                  ),
                ),
                const Divider(),
                Text(
                  'Total paid  ₹${cart.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppTheme.primary,
              ),
              title: const Text(
                'Delivery Location · Home',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(deliveryAddress),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ClinicalDispensing(),
              ),
            ),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Track Live Delivery'),
          ),
        ),
      ),
    );
  }
}

Widget _card(Widget child) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppTheme.outlineBorder),
  ),
  child: child,
);
