import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../orders/order_history.dart';

class DeliveryConfirmation extends StatelessWidget {
  const DeliveryConfirmation({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PharmaCustomer'),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(22),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 68, bottom: 8),
            child: Text(
              'Delivery Complete / Verification',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _card(
          Column(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: AppTheme.surfaceLow,
                child: Icon(
                  Icons.verified,
                  color: AppTheme.primaryDark,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verified Delivery Partner  ★ 4.9',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Assigned Fulfillment Hub · Arrived at Door',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const Divider(height: 26),
              const Text(
                'Safe Contactless Protocol Active · Live GPS Match',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '♙  HANDOVER SECURITY PIN',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Share OTP with Rider',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Rider requires this unique 4-digit code to complete verified release.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              const Text(
                '8    4    9    2',
                style: TextStyle(
                  fontSize: 30,
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safe handoff confirmed')),
                  ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('1-Tap Confirm Safe Handoff'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bypasses manual OTP entry via encrypted proximity',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const OrderHistory()),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm Received & Healthy'),
              ),
            ),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Report a transit issue'),
                  content: const Text(
                    'Describe any damaged or missing items. Support will review your report.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transit defect report submitted'),
                          ),
                        );
                      },
                      child: const Text('Submit report'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(
                Icons.warning_amber_outlined,
                color: AppTheme.error,
              ),
              label: const Text(
                'Report Transit Defect / Damage',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _card(Widget child) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppTheme.outlineBorder),
  ),
  child: child,
);
