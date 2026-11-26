import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';

Future<PlatformFile?> showPrescriptionUploadSheet(BuildContext context) =>
    showModalBottomSheet<PlatformFile?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrescriptionUploadSheet(),
    );

class _PrescriptionUploadSheet extends StatefulWidget {
  const _PrescriptionUploadSheet();

  @override
  State<_PrescriptionUploadSheet> createState() =>
      _PrescriptionUploadSheetState();
}

class _PrescriptionUploadSheetState extends State<_PrescriptionUploadSheet> {
  bool _consent = false;
  bool _picking = false;

  Future<void> _pick({bool pdf = false, bool camera = false}) async {
    setState(() => _picking = true);
    try {
      if (camera) {
        final image = await ImagePicker().pickImage(source: ImageSource.camera);
        if (!mounted) return;
        if (image != null) {
          final size = await image.length();
          if (!mounted) return;
          final file = PlatformFile(name: image.name, path: image.path, size: size);
          if (file.size > 15 * 1024 * 1024) {
            AppToast.error(context, 'Choose a file smaller than 15 MB.');
          } else {
            Navigator.pop(context, file);
          }
        }
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        type: pdf ? FileType.custom : FileType.image,
        allowedExtensions: pdf ? ['pdf'] : null,
        allowMultiple: false,
        withData: true,
      );
      if (!mounted) return;
      final file = result?.files.firstOrNull;
      if (file != null) {
        if (file.size > 15 * 1024 * 1024) {
          AppToast.error(context, 'Choose a file smaller than 15 MB.');
        } else {
          Navigator.pop(context, file);
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not open the selected file.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .88,
    minChildSize: .65,
    maxChildSize: .96,
    expand: false,
    builder: (context, controller) => Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E0E0),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upload Prescription',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const Text(
            'Our certified pharmacists will review and add medicines to your cart in 10 minutes',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'SELECT METHOD',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              letterSpacing: .6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _method(
                  Icons.camera_alt_outlined,
                  'Take Photo',
                  'Use camera',
                  () => _pick(camera: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _method(
                  Icons.photo_library_outlined,
                  'Upload Gallery',
                  'PNG, JPG supported',
                  () => _pick(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _method(
                  Icons.description_outlined,
                  'Upload PDF',
                  'Prescription file',
                  () => _pick(pdf: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _guidelines(),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _consent,
              onChanged: (value) => setState(() => _consent = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I have a valid prescription for myself or a family member',
                style: TextStyle(fontSize: 13, color: AppTheme.text),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _consent && !_picking ? () => _pick() : null,
              icon: _picking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Proceed to Upload'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _method(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => InkWell(
    onTap: _picking ? null : onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 132,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBFD),
        border: Border.all(color: const Color(0xFFD1EAF0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primary,
            child: Icon(icon),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _guidelines() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FBFD),
      border: Border.all(color: const Color(0xFFD9EDF2)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.rule_outlined, color: AppTheme.primary, size: 19),
            SizedBox(width: 8),
            Text(
              'Prescription Guidelines',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _guidelineBlock('✓  Do include:', const Color(0xFF126A6D), [
          'Doctor’s name & qualification',
          'Clinic or hospital letterhead',
          'Patient name & consult date',
          'Doctor’s stamp / signature',
        ]),
        const SizedBox(height: 10),
        _guidelineBlock('ⓧ  Avoid:', const Color(0xFF9F4747), [
          'Blurry or shadowy captures',
          'Cropped dates or doctor details',
          'Partial medicine dosage lists',
          'Expired / outdated prescriptions',
        ]),
      ],
    ),
  );

  Widget _guidelineBlock(String title, Color color, List<String> items) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '•  $item',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
