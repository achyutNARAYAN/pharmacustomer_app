import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Card showing doctor dosage, therapeutic indication, and precaution warning.
class ClinicalInstructionsCard extends StatelessWidget {
  const ClinicalInstructionsCard({super.key});

  @override
  Widget build(BuildContext context) {
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
          _dosageBox(),
          const SizedBox(height: 14),
          const Text('THERAPEUTIC INDICATION',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mutedText,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          const Text(
              'Type 2 Diabetes Mellitus glycemic control alongside diet and exercise.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          _precautionBox(),
        ],
      ),
    );
  }

  Widget _dosageBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            SizedBox(height: 8),
            Text(
              '"1 tablet twice daily after meals (Morning & Night)"',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: AppTheme.text,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text('Authorized by Registered Pharmacist  •  Follow meal schedule strictly',
                style: TextStyle(fontSize: 10, color: AppTheme.mutedText)),
          ],
        ),
      );

  Widget _precautionBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.warningText.withValues(alpha: 0.3)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 16, color: AppTheme.warningText),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Important Precaution: Mild nausea, headache may occur during '
                'initial days. Do not skip meals to prevent hypoglycemia.',
                style: TextStyle(fontSize: 11, color: AppTheme.warningText),
              ),
            ),
          ],
        ),
      );
}
