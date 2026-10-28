import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'prescription_status.dart';

class PrescriptionRejection extends StatelessWidget {
  const PrescriptionRejection({super.key});

  @override
  Widget build(BuildContext context) => StatusScaffold(
    title: 'Prescription Status',
    subtitle: 'CLINICAL REVIEW DECISION',
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDCD9),
            border: Border.all(color: const Color(0xFFF0A8A2)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ORDER BLOCKED  •  CDSCO Regulated',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Prescription Not Approved for Dispensing',
                style: TextStyle(
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'The reviewing pharmacist declined fulfillment under statutory Schedule H / H1 compliance rules of the Indian Drugs and Cosmetics Act.',
                style: TextStyle(color: Color(0xFF9B2929), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        statusPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Audit Deficiency Report',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Divider(height: 24),
              _Issue(
                'Patient Name Mismatch',
                'The recipient profile name does not match the prescription holder on the submitted medical record.',
              ),
              SizedBox(height: 10),
              _Issue(
                'Lapsed Medical Validity (> 6 Months)',
                'Doctor consultation date exceeds the statutory 6-month dispensing validity window.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        statusPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Affected Schedule Drugs (2)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(height: 20),
              MedicineRow(medicines[1], status: 'Dispensing Prohibited'),
              MedicineRow(medicines[2], status: 'Dispensing Prohibited'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        statusPanel(
          border: const Color(0xFFB9E4DF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Prepaid Amount Protected  ₹1,507.00',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Auto-Refund Initiated',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Full payment of ₹1,507.00 will be auto-refunded to your original payment method (Razorpay UPI) within 2–4 business days.',
              ),
              Divider(height: 24),
              Text(
                'Refund Reference: #RF-882910   •   Track Status',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Different Prescription'),
        ),
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Browse OTC products from Search.')),
          ),
          child: const Text('Browse OTC & Health Wellness (No Rx Required)'),
        ),
      ],
    ),
  );
}

class _Issue extends StatelessWidget {
  final String title, detail;
  const _Issue(this.title, this.detail);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FAFD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ⓧ  $title',
          style: const TextStyle(
            color: Color(0xFFB23D32),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(detail, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    ),
  );
}
