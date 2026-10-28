import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';
import 'payment.dart';

class DeliveryOptions extends StatefulWidget {
  const DeliveryOptions({super.key});
  @override
  State<DeliveryOptions> createState() => _DeliveryOptionsState();
}

class _DeliveryOptionsState extends State<DeliveryOptions> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileNotifier>();
    final deliveryAddress = profile.address.isNotEmpty ? profile.address : 'Saved primary address';
    final deliveryArea = profile.address.isNotEmpty ? 'Verified delivery location' : 'Default delivery destination';

    return Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      title: const Text('Delivery Options'),
      centerTitle: true,
      toolbarHeight: 64,
      actions: const [
        Center(
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Text('Step 2 of 3'),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            value: .66,
            minHeight: 6,
            backgroundColor: AppTheme.surfaceContainerDim,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.outlineBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppTheme.surfaceLow, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.location_on, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivering to: $deliveryAddress', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(deliveryArea, style: const TextStyle(color: AppTheme.mutedText)),
                ],
              )),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 30, bottom: 18),
          child: Text(
            'Choose your delivery speed',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ),
        ...[
          (Icons.bolt, 'Lightning Express', 'Fastest option · 22 mins'),
          (
            Icons.calendar_month,
            'Eco / Scheduled Delivery',
            'Choose a convenient 2-hour window and save ₹20 eco-credit',
          ),
        ].asMap().entries.map(
          (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: selected == entry.key
                          ? AppTheme.primary
                          : AppTheme.outlineBorder,
                      width: selected == entry.key ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => selected = entry.key),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                          width: 56,
                          height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLow,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              entry.value.$1,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(entry.value.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (entry.key == 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: AppTheme.successBg, borderRadius: BorderRadius.circular(12)),
                                        child: const Text('22 mins', style: TextStyle(fontSize: 11, color: AppTheme.successText, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value.$3,
                                  style: const TextStyle(
                                  fontSize: 14,
                                    color: AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                                if (entry.key == 0) ...[
                                  const Divider(height: 20),
                                  const Text(
                                    'Fastest option · Dispatched from nearest verified fulfillment center',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.mutedText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selected == entry.key
                                ? Icons.check_circle
                                : Icons.radio_button_off,
                            color: selected == entry.key
                                ? AppTheme.primary
                                : AppTheme.textDisabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (entry.key == 0)
                  Positioned(
                    right: 18,
                    top: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'RECOMMENDED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Container(
        color: AppTheme.background,
        padding: const EdgeInsets.only(top: 8),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 15,
                color: AppTheme.successText,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Insured medical courier transit',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              Text(
                'All Items in Stock',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const Payment()),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${context.watch<CartNotifier>().totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Inclusive of all medical taxes',
                        style: TextStyle(
                        fontSize: 11,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('Proceed to Payment', textAlign: TextAlign.right)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                  ),
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

