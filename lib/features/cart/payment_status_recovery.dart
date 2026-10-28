import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'payment_declined.dart';
import 'payment_processing.dart';

class PaymentStatusRecovery extends StatelessWidget {
  const PaymentStatusRecovery({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
      title: const Text('PharmaCustomer'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        const Text(
          'TRANSACTION RECONCILIATION',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Verifying Payment & Syncing Order',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 18,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.outlineBorder),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: AppTheme.surfaceLow,
                child: Icon(Icons.sync, color: AppTheme.primary, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Restoring Order Status…',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'We are verifying your transaction with your bank. If money was debited, your order will confirm automatically without double charge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Divider(height: 28),
              const Row(
                children: [
                  Expanded(
                    child: _Info(
                      'Order reference',
                      '#AC-9941 · ₹1,507.00',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _Info('Gateway tracking', 'RZP_ORDER_98192746'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medication summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 14),
              _Line('Janumet 50mg/500mg', '₹485.00'),
              Divider(),
              _Line('Rosuvas 10mg', '₹1,022.00'),
              Divider(),
              _Line('Total committed (incl. taxes)', '₹1,507.00', bold: true),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(value: .4, minHeight: 6),
        ),
        const SizedBox(height: 8),
        const Text(
          'Checking with your bank · Next update in 10s',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.mutedText),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaymentProcessing(amount: 1507),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('I was charged · Check status'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaymentDeclined(),
                  ),
                ),
                icon: const Icon(Icons.hourglass_bottom),
                label: const Text('Still pending · See retry options'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.name, this.value, {this.bold = false});
  final String name;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          name,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
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
  );
}
