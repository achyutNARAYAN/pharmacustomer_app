import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'delivery_confirmation.dart';

class DoorstepVerification extends StatelessWidget {
  const DoorstepVerification({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('pharmaCustomer · #AC-9941')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'At Doorstep · Awaiting Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.delivery_dining, color: Colors.white),
                ),
                title: Text(
                  'Ramesh Kumar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Verified pharmaCustomer Fleet Partner'),
                trailing: Icon(Icons.call_outlined, color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text(
                      'HANDOVER VERIFICATION CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '8492',
                      style: TextStyle(
                        fontSize: 34,
                        letterSpacing: 10,
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Share only after inspecting the tamper-evident seal and medicine packaging.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pay ₹1,507 via Doorstep Dynamic UPI QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'QR ready · Auto-polling server verification',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Secure payment QR'),
                        content: const SizedBox(
                          height: 190,
                          child: Center(
                            child: Icon(
                              Icons.qr_code_2,
                              size: 150,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Show QR'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Bill Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _row('Janumet 50mg/500mg', '₹485.00'),
              _row('Rosuvas 10mg', '₹1,022.00'),
              _row('Platform healthcare subsidy', '−₹161.00'),
              _row('GST & clinical dispatch toll', '₹161.46'),
              const Divider(),
              _row('Total', '₹1,507.00', bold: true),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DeliveryConfirmation(),
              ),
            ),
            child: const Text('Verify handover & continue'),
          ),
        ),
      ),
    ),
  );
}

Widget _card(Widget child) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppTheme.outlineBorder),
  ),
  child: child,
);
Widget _row(String label, String value, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: bold ? AppTheme.primaryDark : AppTheme.text,
        ),
      ),
    ],
  ),
);
