import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/theme.dart';
import 'prescription_status.dart';

class PrescriptionReviewStatus extends StatelessWidget {
  final List<PlatformFile>? files;

  const PrescriptionReviewStatus({
    super.key,
    this.files,
  });

  @override
  Widget build(BuildContext context) => StatusScaffold(
    title: 'Prescription Review #RX-884920',
    subtitle: 'Verified by Licensed Clinical Team',
    bottom: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            for (final item in medicines) {
              final id = 'rx_${item.$1}';
              if (context.read<CartNotifier>().quantityOf(id) == 0) {
                context.read<CartNotifier>().add(
                  CartItem(
                    id: id,
                    name: item.$1,
                    pack: item.$2,
                    price: item.$3,
                  ),
                );
              }
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('3 approved medicines added to your cart.'),
              ),
            );
          },
          icon: const Icon(Icons.shopping_cart_outlined),
          label: const Text('Move 3 Medicines to Cart (₹1,507.00)'),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statusPanel(
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFD0EAE7),
                child: Icon(Icons.verified, color: AppTheme.primary),
              ),
              SizedBox(width: 12),
              Text(
                'Pharmacist Review Complete',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        statusPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.description_outlined, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original Prescription Document',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Uploaded by patient • 1 page validated',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 0.77,
                  child: files?.isNotEmpty == true
                      ? _DocPreview(file: files!.first)
                      : const ColoredBox(
                          color: Color(0xFFEAF9FD),
                          child: Center(
                            child: Icon(
                              Icons.article_outlined,
                              size: 56,
                              color: Color(0xFF8CAEB5),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 12),
          child: Text(
            'Itemized Prescriptions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        ...medicines.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: statusPanel(child: MedicineRow(item)),
          ),
        ),
      ],
    ),
  );
}

// ── Document preview ───────────────────────────────────────────────────────

class _DocPreview extends StatefulWidget {
  final PlatformFile file;
  const _DocPreview({required this.file});

  @override
  State<_DocPreview> createState() => _DocPreviewState();
}

class _DocPreviewState extends State<_DocPreview> {
  Future<Uint8List>? _pdfThumb;

  bool get _isImage => const ['.png', '.jpg', '.jpeg', '.webp']
      .any(widget.file.name.toLowerCase().endsWith);

  @override
  void initState() {
    super.initState();
    if (!_isImage &&
        widget.file.name.toLowerCase().endsWith('.pdf') &&
        widget.file.bytes != null) {
      _pdfThumb = Printing.raster(
        widget.file.bytes!,
        pages: const [0],
        dpi: 220,
      ).first.then((p) => p.toPng());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage && widget.file.bytes != null) {
      return Image.memory(widget.file.bytes!, fit: BoxFit.contain);
    }
    if (_pdfThumb != null) {
      return FutureBuilder<Uint8List>(
        future: _pdfThumb,
        builder: (context, snap) {
          if (snap.hasData) return Image.memory(snap.data!, fit: BoxFit.contain);
          if (snap.hasError) return _fallback();
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        },
      );
    }
    return _fallback();
  }

  Widget _fallback() => const ColoredBox(
    color: Color(0xFFEAF9FD),
    child: Center(
      child: Icon(Icons.article_outlined, size: 56, color: Color(0xFF8CAEB5)),
    ),
  );
}
