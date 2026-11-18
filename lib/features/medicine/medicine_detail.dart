import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/models/medicine_model.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../prescriptions/prescription_review.dart';
import '../prescriptions/prescription_upload_sheet.dart';
import '../prescriptions/providers/prescription_provider.dart';
import '../prescriptions/repositories/prescription_repository.dart';
import 'widgets/clinical_instructions_card.dart';
import 'widgets/delivery_banner.dart';
import 'widgets/medicine_hero_card.dart';
import 'widgets/prescription_required_banner.dart';

class MedicineDetail extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetail({super.key, required this.medicine});

  @override
  State<MedicineDetail> createState() => _MedicineDetailState();
}

class _MedicineDetailState extends State<MedicineDetail> {
  late Medicine _medicine;
  bool _isPrescriptionUploaded = false;
  int _quantity = 1;

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

  bool get _canAddToCart =>
      !_medicine.requiresPrescription || _isPrescriptionUploaded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: const BackButton(color: AppTheme.text),
        title: const Text(
          'Medicine Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border, color: AppTheme.text), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share_outlined, color: AppTheme.text), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_canAddToCart) ...[
              const DeliveryBanner(),
              const SizedBox(height: 16),
            ],
            MedicineHeroCard(medicine: _medicine),
            const SizedBox(height: 16),
            if (!_canAddToCart)
              const PrescriptionRequiredBanner()
            else
              const ClinicalInstructionsCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final price = double.tryParse(_medicine.price.replaceAll('₹', '').replaceAll(',', '').trim()) ?? 0.0;
    final cartId = _medicine.id ?? _medicine.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outlineBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_canAddToCart)
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payable Amount', style: TextStyle(fontSize: 11, color: AppTheme.mutedText)),
                    Row(
                      children: [
                        Text('₹${_medicine.price}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text)),
                        const SizedBox(width: 6),
                        Text('₹${_medicine.mrp}',
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough, color: AppTheme.mutedText, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final profile = context.read<ProfileNotifier?>();
                        final pName = (profile?.name.isNotEmpty ?? false) ? profile!.name : 'Customer';
                        final cart = context.read<CartNotifier>();

                        final file = await showPrescriptionUploadSheet(context);
                        if (file != null && mounted) {
                          final uploadedRx = await nav.push<Prescription?>(
                            MaterialPageRoute<Prescription?>(
                              builder: (_) => PrescriptionReview(
                                file: file,
                                patientName: pName,
                              ),
                            ),
                          );
                          if (uploadedRx != null && mounted) {
                            setState(() => _isPrescriptionUploaded = true);
                            cart.attachPrescriptionId(uploadedRx.id);
                          }
                        }
                      },
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
            )
          else
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.outlineBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18, color: AppTheme.primary),
                        onPressed: () => setState(() => _quantity = (_quantity - 1).clamp(1, 50)),
                      ),
                      Text('$_quantity',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18, color: AppTheme.primary),
                        onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 50)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final cart = context.read<CartNotifier>();
                      final item = CartItem(
                        id: cartId,
                        name: _medicine.name,
                        pack: _medicine.tag ?? '',
                        price: price,
                        quantity: _quantity,
                        requiresPrescription: _medicine.requiresPrescription,
                      );
                      cart.addMedicine(cartId, quantity: _quantity, localFallback: item);

                      if (_medicine.requiresPrescription && !cart.hasPrescriptionAttached) {
                        final rxProv = context.read<PrescriptionProvider?>();
                        final approved = rxProv?.prescriptions
                            .where((p) => p.status == PrescriptionStatus.approved)
                            .toList();
                        if (approved != null && approved.isNotEmpty) {
                          cart.attachPrescriptionId(approved.first.id);
                        }
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$_quantity × ${_medicine.name} added to cart'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Add to Cart  ₹${(price * _quantity).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security_outlined, size: 12, color: AppTheme.mutedText),
              SizedBox(width: 4),
              Text('Genuine medicine • Verified pharmacy',
                  style: TextStyle(fontSize: 10, color: AppTheme.mutedText)),
            ],
          ),
        ],
      ),
    );
  }
}
