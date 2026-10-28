import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/models/medicine_model.dart';
import '../../core/utils/prescription_uploader.dart';
import 'medicine_detail_extended.dart';
import 'widgets/medicine_hero_card.dart';
import 'widgets/prescription_required_banner.dart';

/// Prescription-upload variant — shown when Rx is required and the user
/// hasn't yet uploaded a prescription.
class MedicineDetail extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetail({super.key, required this.medicine});

  @override
  State<MedicineDetail> createState() => _MedicineDetailState();
}

class _MedicineDetailState extends State<MedicineDetail> {
  late Medicine _medicine;

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
    _fetchLiveDetails();
  }

  Future<void> _fetchLiveDetails() async {
    final id = widget.medicine.id;
    if (id != null && id.isNotEmpty) {
      try {
        final data = await ApiService.getMedicineById(id);
        if (data != null && mounted) {
          setState(() {
            _medicine = Medicine.fromJson(data);
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MedicineHeroCard(medicine: _medicine),
            const SizedBox(height: 16),
            const PrescriptionRequiredBanner(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: const BackButton(color: AppTheme.text),
      title: const Text('Medicine Details',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.text)),
      actions: [
        IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.text),
            onPressed: () {}),
        IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.text),
            onPressed: () {}),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outlineBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Payable Amount',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.mutedText)),
                  Row(
                    children: [
                      Text('₹${_medicine.price}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.text)),
                      const SizedBox(width: 6),
                      Text('₹${_medicine.mrp}',
                          style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppTheme.mutedText,
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => pickPrescription(
                      context,
                      onFilePicked: (_) => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MedicineDetailExtended(medicine: _medicine)),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload prescription',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security_outlined,
                  size: 12, color: AppTheme.mutedText),
              SizedBox(width: 4),
              Text(
                  'Genuine medicine • Verified pharmacy',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.mutedText)),
            ],
          ),
        ],
      ),
    );
  }
}
