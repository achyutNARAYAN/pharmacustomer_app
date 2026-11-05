import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../prescriptions/prescription_upload_sheet.dart';

/// Full-width teal banner prompting the user to upload a prescription.
class PrescriptionBanner extends StatelessWidget {
  final ValueChanged<PlatformFile>? onUploadSelected;

  const PrescriptionBanner({super.key, this.onUploadSelected});

  Future<void> _openUpload(BuildContext context) async {
    final file = await showPrescriptionUploadSheet(context);
    if (file != null) onUploadSelected?.call(file);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.crop_free, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order with\nPrescription',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Pharmacist verified in 2–4 hrs',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openUpload(context),
            icon: const Icon(Icons.upload_file, size: 16, color: AppTheme.primary),
            label: const Text('Upload Req',
                style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
