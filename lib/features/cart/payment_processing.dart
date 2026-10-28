import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'payment_declined.dart';
import 'payment_status_recovery.dart';
import 'order_placed.dart';

class PaymentProcessing extends StatelessWidget {
  const PaymentProcessing({super.key, required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '✚  pharmaCustomer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const Spacer(),
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 28),
          const Text(
            'Securing Payment &\nProcessing Order…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Please keep this screen open while we confirm.'),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.outlineBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MERCHANT ENTITY',
                  style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                ),
                const Text(
                  'pharmaCustomer Health Technologies Ltd.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order total · ₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.primaryDark),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const OrderPlaced(),
                      ),
                    ),
                    child: const Text('Payment confirmed · Continue'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PaymentStatusRecovery(),
                    ),
                  ),
                  child: const Text('Still waiting? Check status'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PaymentDeclined(),
                    ),
                  ),
                  child: const Text('Payment was declined'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
