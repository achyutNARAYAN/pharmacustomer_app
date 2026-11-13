import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../cart/cart.dart';

Future<void> showPrescriptionRefillSheet(
  BuildContext context, {
  String doctorName = 'Prescribing Physician',
  String medicineInfo = 'Authorized refill active',
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctorName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(medicineInfo),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppTheme.primary,
                  ),
                  title: const Text('View Cart & Prescribed Medicines'),
                  subtitle: const Text('Review and order approved items'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const Cart()),
                    );
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.history, color: AppTheme.primary),
                  title: const Text('View refill & dispense history'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
