import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme.dart';

Future<void> showPrescriptionDetailSheet(
  BuildContext context, {
  required VoidCallback onArchive,
  String? prescriptionId,
  String doctorName = 'Prescribing Physician',
  String doctorSpecialty = 'Clinical Prescription',
  String prescriptionDetail = 'Verified & Stored in Vault',
}) async {
  String doc = doctorName;
  String detail = prescriptionDetail;

  if (prescriptionId != null && prescriptionId.isNotEmpty && ApiService.token != null) {
    try {
      final data = await ApiService.getPrescriptionById(prescriptionId);
      if (data != null) {
        if (data['doctorName'] != null) doc = data['doctorName'] as String;
        if (data['status'] != null) {
          final approvedList = (data['approvedMedicines'] as List?)?.length ?? 0;
          detail = 'Status: ${data['status']} • $approvedList Approved Medicine(s)';
        }
      }
    } catch (_) {}
  }

  if (!context.mounted) return;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Material(
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
            ListTile(
              leading: _IconTile(Icons.shopping_bag_outlined),
              title: const Text('Order Prescribed Medicines'),
              subtitle: const Text(
                'Automated cart loading • Express delivery available',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: _IconTile(Icons.history),
              title: const Text('View Refill & Dispense History'),
              subtitle: const Text('Fulfillment log and verification timestamps'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: _IconTile(Icons.archive_outlined),
              title: const Text(
                'Archive / Deactivate Prescription',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Stops reminder cadence • Move to inactive'),
              trailing: const Icon(Icons.delete_outline, color: Colors.red),
              onTap: () {
                Navigator.pop(sheetContext);
                onArchive();
              },
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
  ),
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
