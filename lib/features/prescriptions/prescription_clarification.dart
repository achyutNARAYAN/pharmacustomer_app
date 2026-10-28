import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'prescription_status.dart';
import 'prescription_upload_sheet.dart';

class PrescriptionClarification extends StatelessWidget {
  const PrescriptionClarification({super.key});

  Future<void> _upload(BuildContext context) async {
    final file = await showPrescriptionUploadSheet(context);
    if (context.mounted && file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.name} uploaded for clarification review.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => StatusScaffold(
    title: 'Prescription Status',
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1EF),
            border: Border.all(color: const Color(0xFFF2C3BB)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clarification Required for Approval',
                      style: TextStyle(
                        color: Color(0xFFAA382D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Our licensed pharmacist reviewed your prescription but needs additional information to dispense Schedule H medication safely.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        statusPanel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registered Reviewing Pharmacist',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Clinical Quality Assurance Lead',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Divider(height: 24),
              Text(
                'CLINICAL NOTE',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '“The dosage strength for Sitagliptin in line 2 is partially blurred by lighting glare, and the hospital clinic stamp at the bottom right is cropped. Please upload a full, clearer image or speak with our tele-consultant.”',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        statusPanel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uploaded Document',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Divider(height: 24),
              SizedBox(
                height: 105,
                child: Center(
                  child: Icon(
                    Icons.document_scanner_outlined,
                    size: 76,
                    color: Color(0xFF78969B),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Tap preview to inspect annotated areas',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 22, bottom: 10),
          child: Text(
            'How would you like to resolve this?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        statusPanel(
          border: AppTheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Clearer Prescription Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Retake in flat, well-lit conditions ensuring the clinic header and stamp are visible.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _upload(context),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _upload(context),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('From Gallery'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTC product browsing is available from Search.'),
            ),
          ),
          child: const Text(
            'Browse OTC & Health Products (No Prescription Required)',
          ),
        ),
      ],
    ),
  );
}
