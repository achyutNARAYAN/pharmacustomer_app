import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/models/medicine_model.dart';
import 'widgets/clinical_instructions_card.dart';
import 'widgets/delivery_banner.dart';
import 'widgets/medicine_hero_card_extended.dart';

class MedicineDetailExtended extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetailExtended({super.key, required this.medicine});

  @override
  State<MedicineDetailExtended> createState() => _MedicineDetailExtendedState();
}

class _MedicineDetailExtendedState extends State<MedicineDetailExtended> {
  int _quantity = 1;
  late Medicine _medicine;

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
    _fetchLiveDetails();
  }

  Future<void> _fetchLiveDetails() async {
    final medId = widget.medicine.id;
    if (medId != null && medId.isNotEmpty) {
      try {
        final data = await ApiService.getMedicineById(medId);
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
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Medicine Details'),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DeliveryBanner(),
            const SizedBox(height: 16),
            MedicineHeroCardExtended(medicine: _medicine),
            const SizedBox(height: 16),
            const ClinicalInstructionsCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final price = double.tryParse(_medicine.price.replaceAll('₹', '').trim()) ?? 0.0;
    final cartId = _medicine.id ?? _medicine.name;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outlineBorder)),
      ),
      child: Row(
        children: [
          // ── Quantity counter with AnimatedSwitcher ────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.outlineBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18, color: AppTheme.primary),
                  onPressed: () => setState(() => _quantity = (_quantity - 1).clamp(1, 10)),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: child,
                  ),
                  child: Text(
                    '$_quantity',
                    key: ValueKey(_quantity),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18, color: AppTheme.primary),
                  onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 10)),
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
    );
  }
}
