import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'live_tracking.dart';
import 'tax_invoice.dart';
import '../support/clinical_support.dart';

class ClinicalDispensing extends StatelessWidget {
  const ClinicalDispensing({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: const Column(
        children: [
          Text(
            'ORDER #RX-92841',
            style: TextStyle(fontSize: 10, color: AppTheme.mutedText),
          ),
          Text('Clinical Dispensing'),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ClinicalSupport()),
          ),
          icon: const Icon(Icons.help_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _panel(
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: AppTheme.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sterile Cleanroom · In progress',
                      style: TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your pharmacist is preparing this order under certified sterile conditions.',
                      style: TextStyle(
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fulfillment Milestones',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const _Milestone(
                Icons.check_circle,
                'Order Confirmed & Authorized',
                'Prescription cross-referenced against health record',
                done: true,
              ),
              const _Milestone(
                Icons.check_circle,
                'Clinical Verification',
                'Drug interaction checks passed',
                done: true,
              ),
              const _Milestone(
                Icons.qr_code_scanner,
                'Batch Picking & Barcode Verification',
                '2 of 3 items scanned · Pharmacist is checking each pack',
                active: true,
              ),
              const _Milestone(
                Icons.ac_unit,
                'Cold-Chain Seal & Tamper Tagging',
                'Upcoming',
              ),
              const _Milestone(
                Icons.delivery_dining,
                'Courier Handover',
                'Estimated dispatch 3:15 PM',
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LiveTracking()),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Live Fulfillment & Map'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Navigate to the tax invoice screen
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const TaxInvoice(),
                    ),
                  );
                  // Generate and save to device documents/downloads + share
                  try {
                    await generateAndSaveInvoicePdf();
                  } catch (_) {}
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download Invoice'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Milestone extends StatelessWidget {
  const _Milestone(
    this.icon,
    this.title,
    this.detail, {
    this.done = false,
    this.active = false,
  });
  final IconData icon;
  final String title, detail;
  final bool done, active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: done ? const Color(0xFFCDE8E3) : AppTheme.surfaceLow,
          child: Icon(
            icon,
            size: 19,
            color: active || done ? AppTheme.primary : AppTheme.mutedText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: done || active ? AppTheme.text : AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (active)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(value: .66, minHeight: 6),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _panel(Widget child) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppTheme.outlineBorder),
  ),
  child: child,
);
