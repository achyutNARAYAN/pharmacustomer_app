import 'package:flutter/material.dart';
import '../../../core/models/medicine_model.dart';
import '../../../core/theme.dart';

/// Hero card shown on MedicineDetail (prescription-upload variant).
/// Displays image placeholder, pack tag, name, composition, and price.
class MedicineHeroCard extends StatelessWidget {
  final Medicine medicine;
  const MedicineHeroCard({super.key, required this.medicine});

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
          _imagePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _packTag(),
                const SizedBox(height: 10),
                Text(medicine.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppTheme.text)),
                const SizedBox(height: 12),
                _compositionBox(),
                const SizedBox(height: 14),
                _priceRow(),
                const SizedBox(height: 4),
                const Text('Inclusive of all applicable taxes',
                    style: TextStyle(fontSize: 11, color: AppTheme.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 150,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.medication, size: 54, color: AppTheme.primary),
          ),
        ),
      );

  Widget _packTag() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 14, color: AppTheme.primary),
            SizedBox(width: 4),
            Text('Strip of 15 Tablets',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _compositionBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, size: 16, color: AppTheme.mutedText),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Salts (Composition)',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.mutedText)),
                  SizedBox(height: 2),
                  Text(
                      'Sitagliptin (50mg) + Metformin\nHydrochloride (500mg)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.text)),
                ],
              ),
            ),
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
          Text('MRP ₹${medicine.mrp}',
              style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppTheme.mutedText,
                  fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(medicine.discount,
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      );
}
