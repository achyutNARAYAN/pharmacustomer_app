import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../repositories/prescription_repository.dart';

Future<void> showPrescriptionDetailSheet(
  BuildContext context, {
  required VoidCallback onArchive,
  Future<void> Function()? onDelete,
  String? prescriptionId,
  PrescriptionStatus status = PrescriptionStatus.approved,
  String doctorName = 'Prescribing Physician',
  String doctorSpecialty = 'Clinical Prescription',
  String prescriptionDetail = 'Verified & Stored in Vault',
}) {
  final doc = doctorName;
  String detail = prescriptionDetail;

  if (prescriptionDetail == 'Verified & Stored in Vault') {
    switch (status) {
      case PrescriptionStatus.underReview:
        detail = 'Under Review • Pharmacist verification in progress';
        break;
      case PrescriptionStatus.rejected:
        detail = 'Rejected • Schedule H requirements not met';
        break;
      case PrescriptionStatus.expired:
        detail = 'Expired • Valid validity period has lapsed';
        break;
      default:
        detail = 'Verified & Stored in Vault';
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Future<void> confirmDelete() async {
        final confirmed = await showDialog<bool>(
          context: sheetContext,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Delete Prescription?'),
              ],
            ),
            content: const Text(
              'Are you sure you want to permanently delete this prescription? '
              'This document will be removed from your vault and active carts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Delete Permanently'),
              ),
            ],
          ),
        );

        if (confirmed == true && sheetContext.mounted) {
          Navigator.pop(sheetContext);
          if (onDelete != null) {
            await onDelete();
          }
        }
      }

      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E0E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const _IconTile(Icons.medical_information_outlined, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            doctorSpecialty,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF7FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                if (status == PrescriptionStatus.approved) ...[
                  ListTile(
                    leading: const _IconTile(Icons.shopping_bag_outlined),
                    title: const Text('Order Prescribed Medicines'),
                    subtitle: const Text(
                      'Automated cart loading • Express delivery available',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheetContext),
                  ),
                  ListTile(
                    leading: const _IconTile(Icons.history),
                    title: const Text('View Refill & Dispense History'),
                    subtitle: const Text('Fulfillment log and verification timestamps'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheetContext),
                  ),
                  ListTile(
                    leading: const _IconTile(Icons.archive_outlined),
                    title: const Text(
                      'Archive / Deactivate Prescription',
                      style: TextStyle(color: Colors.amber),
                    ),
                    subtitle: const Text('Stops reminder cadence • Move to inactive'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onArchive();
                    },
                  ),
                ],
                if (status == PrescriptionStatus.underReview ||
                    status == PrescriptionStatus.rejected ||
                    status == PrescriptionStatus.expired)
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 21),
                    ),
                    title: const Text(
                      'Delete Prescription Permanently',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Remove file and records from account'),
                    trailing: const Icon(Icons.delete_outline, color: Colors.red),
                    onTap: confirmDelete,
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close Sheet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IconTile(this.icon, {this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFDDF6FB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppTheme.primary, size: size * .48),
  );
}
