import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme.dart';
import 'prescription_review_status.dart';
import 'prescription_upload_sheet.dart';

// ── Constants ────────────────────────────────────────────────────────────────

const _kBg = Color(0xFFF0FBFF);
const _kSurface = Colors.white;
const _kThumbnailW = 68.0;
const _kThumbnailH = 88.0;

// ── Review screen ────────────────────────────────────────────────────────────

class PrescriptionReview extends StatefulWidget {
  final PlatformFile file;
  final String patientName;
  final String? patientId;
  final List<String> allergies;
  final String? profileImagePath;

  const PrescriptionReview({
    super.key,
    required this.file,
    required this.patientName,
    this.patientId,
    this.allergies = const [],
    this.profileImagePath,
  });

  @override
  State<PrescriptionReview> createState() => _PrescriptionReviewState();
}

class _PrescriptionReviewState extends State<PrescriptionReview> {
  late final List<PlatformFile> _files = [widget.file];
  late final List<Future<Uint8List>?> _pdfPreviews = [
    _loadPdfPreview(widget.file),
  ];
  int _selectedPage = 0;

  bool get _isImage => const [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  ].any(_files[_selectedPage].name.toLowerCase().endsWith);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: _appBar(),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _documentPreviewCard(),
              const SizedBox(height: 20),
              _pageStripSection(),
            ],
          ),
        ),
        _submitBar(),
      ],
    ),
  );

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar() => AppBar(
    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
    ),
    title: Column(
      children: [
        const Text('Review Prescription'),
        Text(
          'Page ${_selectedPage + 1} of ${_files.length}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.normal,
            color: AppTheme.mutedText,
          ),
        ),
      ],
    ),
    centerTitle: true,
    actions: [
      TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.delete_outline_rounded,
          size: 16,
          color: AppTheme.error,
        ),
        label: const Text(
          'Discard',
          style: TextStyle(fontSize: 12, color: AppTheme.error),
        ),
      ),
      const SizedBox(width: 4),
    ],
  );


  // ── Document preview ───────────────────────────────────────────────────────

  Widget _documentPreviewCard() => Container(
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.outlineBorder),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: .06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _files[_selectedPage].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      'Page ${_selectedPage + 1} of ${_files.length} • Tap to review',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✓  Uploaded',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Divider
        const Divider(height: 1),
        // Preview
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          child: AspectRatio(aspectRatio: .78, child: _preview()),
        ),
      ],
    ),
  );

  // ── Page strip ─────────────────────────────────────────────────────────────

  Widget _pageStripSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text(
            'Uploaded Pages',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_files.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _files.length; i++) ...[
              _pageThumbnail(i),
              const SizedBox(width: 10),
            ],
            _addPageButton(),
          ],
        ),
      ),
    ],
  );

  Widget _pageThumbnail(int i) {
    final selected = _selectedPage == i;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedPage = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: _kThumbnailW,
            height: _kThumbnailH,
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryContainer : _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.outlineBorder,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: .18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.insert_drive_file_rounded,
                  color: selected ? AppTheme.primary : AppTheme.mutedText,
                  size: 26,
                ),
                const SizedBox(height: 5),
                Text(
                  'Pg ${i + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.primary : AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_files.length > 1)
          Positioned(
            top: -7,
            right: -7,
            child: GestureDetector(
              onTap: () => _removePage(i),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kSurface, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.error.withValues(alpha: .3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _addPageButton() => GestureDetector(
    onTap: _addPage,
    child: Container(
      width: _kThumbnailW,
      height: _kThumbnailH,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary,
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_rounded, color: AppTheme.primary, size: 26),
          SizedBox(height: 4),
          Text(
            'Add Page',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Submit bar ─────────────────────────────────────────────────────────────

  Widget _submitBar() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit for Pharmacist Review'),
        ),
      ),
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _preview() {
    final file = _files[_selectedPage];
    if (_isImage && file.bytes != null) {
      return Image.memory(
        file.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    if (_pdfPreviews[_selectedPage] case final preview?) {
      return FutureBuilder<Uint8List>(
        future: preview,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _previewMessage(
              'Could not render this PDF.\nYou can still submit it for pharmacist review.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            );
          }
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
        },
      );
    }
    return _placeholder();
  }

  Future<Uint8List>? _loadPdfPreview(PlatformFile file) {
    if (!file.name.toLowerCase().endsWith('.pdf') || file.bytes == null) {
      return null;
    }
    return Printing.raster(
      file.bytes!,
      pages: const [0],
      dpi: 180,
    ).first.then((p) => p.toPng());
  }

  Widget _previewMessage(String message) => Container(
    color: _kBg,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(24),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppTheme.mutedText, height: 1.5),
    ),
  );

  Widget _placeholder() => Container(
    color: AppTheme.primaryContainer,
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.description_rounded, size: 52, color: AppTheme.primary),
        SizedBox(height: 12),
        Text(
          'Document Preview',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Preview not available for this file type',
          style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
        ),
      ],
    ),
  );

  Future<void> _addPage() async {
    final file = await showPrescriptionUploadSheet(context);
    if (!mounted || file == null) return;
    setState(() {
      _files.add(file);
      _pdfPreviews.add(_loadPdfPreview(file));
      _selectedPage = _files.length - 1;
    });
  }

  void _removePage(int i) {
    setState(() {
      _files.removeAt(i);
      _pdfPreviews.removeAt(i);
      if (_selectedPage >= _files.length) _selectedPage = _files.length - 1;
    });
  }


  Future<void> _submit() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PrescriptionSubmitted(files: _files)),
    );
    if (!mounted || submitted != true) return;
    Navigator.pop(context, true);
  }
}

// ── Submitted screen ─────────────────────────────────────────────────────────

class PrescriptionSubmitted extends StatelessWidget {
  final List<PlatformFile> files;

  const PrescriptionSubmitted({super.key, required this.files});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              children: [
                // Success icon
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2F7F6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Prescription Submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Our licensed pharmacists are reviewing your prescription.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.mutedText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                // ETA badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.infoText.withValues(alpha: .2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppTheme.infoText,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Average review time: 30–45 minutes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.infoText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Tracker card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outlineBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Verification Tracker',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.text,
                        ),
                      ),
                      SizedBox(height: 16),
                      _TrackerStep(
                        icon: Icons.check_rounded,
                        title: 'Prescription Uploaded',
                        done: true,
                      ),
                      _TrackerStep(
                        icon: Icons.biotech_rounded,
                        title: 'Under Pharmacist Review',
                        active: true,
                      ),
                      _TrackerStep(
                        icon: Icons.shopping_bag_rounded,
                        title: 'Medicines Added to Cart',
                      ),
                      _TrackerStep(
                        icon: Icons.credit_card_rounded,
                        title: 'Order Ready for Payment',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom actions
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PrescriptionReviewStatus(files: files),
                        ),
                      ),
                      icon: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Track Pharmacist Review'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Browse Products While You Wait'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Tracker step ─────────────────────────────────────────────────────────────

class _TrackerStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool done;
  final bool active;
  final bool isLast;

  const _TrackerStep({
    required this.icon,
    required this.title,
    this.done = false,
    this.active = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Icon + connector line
      Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppTheme.successBg
                  : active
                  ? AppTheme.primaryContainer
                  : AppTheme.mutedBg,
              border: Border.all(
                color: done
                    ? AppTheme.successText
                    : active
                    ? AppTheme.primary
                    : AppTheme.outlineBorder,
                width: active ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: done
                  ? AppTheme.successText
                  : active
                  ? AppTheme.primary
                  : AppTheme.textDisabled,
            ),
          ),
          if (!isLast)
            Container(
              width: 1.5,
              height: 22,
              color: done
                  ? AppTheme.successText.withValues(alpha: .3)
                  : AppTheme.outlineBorder,
            ),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: done || active
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: done || active
                          ? AppTheme.text
                          : AppTheme.textDisabled,
                    ),
                  ),
                  if (active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'In Progress',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              if (!isLast) const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    ],
  );
}
