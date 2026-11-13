import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Card showing doctor dosage, therapeutic indication, and precaution warning.
class ClinicalInstructionsCard extends StatelessWidget {
  final String? indication;
  final String? dosage;
  final String? precaution;

  const ClinicalInstructionsCard({
    super.key,
    this.indication,
    this.dosage,
    this.precaution,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIndication = indication?.isNotEmpty == true
        ? indication!
        : 'Prescription & therapeutic healthcare medication. Refer to medical practitioner guidance.';
    final effectiveDosage = dosage?.isNotEmpty == true
        ? dosage!
        : 'Take as directed by your prescribing physician or as instructed on the package label.';
    final effectivePrecaution = precaution?.isNotEmpty == true
        ? precaution!
        : 'Follow the prescribed dosage strictly. Store in a cool, dry place away from direct sunlight.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medical_information_outlined,
                  size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Clinical Instructions & Usage',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 14),
          _dosageBox(effectiveDosage),
          const SizedBox(height: 14),
          const Text('THERAPEUTIC INDICATION',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mutedText,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(effectiveIndication,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          _precautionBox(effectivePrecaution),
        ],
      ),
    );
  }

  Widget _dosageBox(String dosageText) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 14, color: AppTheme.primary),
                SizedBox(width: 6),
                Text("Doctor's Prescribed Dosage",
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '"$dosageText"',
              style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: AppTheme.text,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text('Authorized by Registered Pharmacist • Follow meal schedule strictly',
                style: TextStyle(fontSize: 10, color: AppTheme.mutedText)),
          ],
        ),
      );

  Widget _precautionBox(String precautionText) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.warningText.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppTheme.warningText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Precaution: $precautionText',
                style: const TextStyle(fontSize: 11, color: AppTheme.warningText),
              ),
            ),
          ],
        ),
      );
}
