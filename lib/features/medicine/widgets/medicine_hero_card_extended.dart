import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/models/medicine_model.dart';

/// Extended hero card for MedicineDetailExtended.
/// Shows temperature badges, pre-approved badge, manufacturer info, and price.
class MedicineHeroCardExtended extends StatelessWidget {
  final Medicine medicine;
  const MedicineHeroCardExtended({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _imageWithBadges(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _preApprovedBadge(),
                const SizedBox(height: 10),
                Text(medicine.name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppTheme.text)),
                const SizedBox(height: 4),
                Text(medicine.description,
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12)),
                const SizedBox(height: 12),
                _InfoRow('Manufacturer', 'MSD Pharmaceuticals Pvt Ltd'),
                const SizedBox(height: 4),
                _InfoRow('Packaging', 'Strip of 15 film-coated tablets'),
                const SizedBox(height: 14),
                _priceRow(),
                const SizedBox(height: 4),
                const Text('Inclusive of all taxes (HSN 3004)',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageWithBadges() => Stack(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Center(
                child:
                    Icon(Icons.medication, size: 72, color: AppTheme.primary)),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('100% Genuine',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text)),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.ac_unit, size: 12, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text('Store below 25°C  •  Controlled Temp',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.text,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _preApprovedBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 13, color: AppTheme.successText),
            SizedBox(width: 4),
            Text('Pre-Approved',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.successText,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _priceRow() => Row(
        children: [
          Text('₹${medicine.price}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppTheme.text)),
          const SizedBox(width: 8),
          Text('₹${medicine.mrp}',
              style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppTheme.mutedText,
                  fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(medicine.discount,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 8),
          const Text('Save ₹65.00',
              style: TextStyle(
                  color: AppTheme.subsidyTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

// ── Shared helper ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.mutedText, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.text))),
        ],
      );
}
