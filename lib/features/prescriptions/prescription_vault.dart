import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../cart/cart.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/customer_support_sheet.dart';
import '../home/search.dart';
import 'prescription_review.dart';
import 'prescription_upload_sheet.dart';
import 'providers/prescription_provider.dart';
import 'repositories/prescription_repository.dart';
import 'widgets/prescription_progress_step.dart';
import 'widgets/prescription_detail_sheet.dart';

class PrescriptionVault extends StatefulWidget {
  final String patientName;
  final String? patientId;
  final List<String> allergies;
  final VoidCallback? onBack;

  const PrescriptionVault({
    super.key,
    required this.patientName,
    this.patientId,
    this.allergies = const [],
    this.onBack,
  });

  @override
  State<PrescriptionVault> createState() => _PrescriptionVaultState();
}

class _PrescriptionVaultState extends State<PrescriptionVault> {
  int _tab = 0;

  Future<void> _onRefresh() async {
    final rxProvider = context.read<PrescriptionProvider?>();
    if (rxProvider != null) {
      await rxProvider.refresh();
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rxProvider = context.watch<PrescriptionProvider?>();
    final allPrescriptions = rxProvider?.prescriptions ?? [];
    final activeList = allPrescriptions
        .where(
          (p) =>
              p.status == PrescriptionStatus.approved ||
              p.status == PrescriptionStatus.uploaded,
        )
        .toList();
    final underReviewList = allPrescriptions
        .where(
          (p) =>
              p.status == PrescriptionStatus.underReview ||
              p.status == PrescriptionStatus.queued ||
              p.status == PrescriptionStatus.uploading,
        )
        .toList();
    final archivedList = allPrescriptions
        .where(
          (p) =>
              p.status == PrescriptionStatus.expired ||
              p.status == PrescriptionStatus.rejected,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _handleBack,
        ),
        title: const Text('Prescription Vault'),
        actions: [
          IconButton(
            tooltip: 'Pharmacist Support',
            onPressed: () => showCustomerSupportSheet(
              context,
              customQuery: 'Hi Pharmacist, I need help with my prescriptions.',
            ),
            icon: const Icon(Icons.support_agent_rounded, color: AppTheme.primary),
          ),
          IconButton(
            onPressed: _showInfo,
            icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _tabs(
            activeCount: activeList.length,
            reviewCount: underReviewList.length,
            archivedCount: archivedList.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppTheme.primary,
              child: _tab == 0
                  ? (activeList.isNotEmpty ? _activeView(activeList) : _emptyView())
                  : _tab == 1
                  ? _underReviewView(underReviewList)
                  : _archivedView(archivedList),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs({
    required int activeCount,
    required int reviewCount,
    required int archivedCount,
  }) => SizedBox(
    height: 64,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      scrollDirection: Axis.horizontal,
      children: [
        _tabChip(0, 'Active Prescriptions', '$activeCount'),
        _tabChip(1, 'Under Review', '$reviewCount'),
        _tabChip(2, 'Past & Expired', '$archivedCount'),
      ],
    ),
  );

  Widget _tabChip(int index, String label, String count) {
    final selected = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Text('$label  $count'),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppTheme.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.outlineBorder,
        ),
        onSelected: (_) => setState(() => _tab = index),
      ),
    );
  }

  Widget _activeView(List<Prescription> list) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      ...list.map(
        (p) {
          final shortId = p.id.length > 8 ? p.id.substring(0, 8) : p.id;
          final displayTitle = (p.doctorName != null && p.doctorName!.trim().isNotEmpty)
              ? p.doctorName!.trim()
              : (p.fileName.trim().isNotEmpty ? p.fileName.trim() : 'Uploaded Prescription');
          final subtitle = p.status == PrescriptionStatus.approved
              ? 'ID: #$shortId • Valid 1 month'
              : 'ID: #$shortId • Uploaded ${_formatDate(p.createdAt)}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _prescriptionCard(
              rxId: p.id,
              rxStatus: p.status,
              name: displayTitle,
              subtitle: subtitle,
              date: _formatDate(p.createdAt),
              status: p.status.chipLabel,
            ),
          );
        },
      ),
    ],
  );

  Widget _emptyView() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.outlineBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: .07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppTheme.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your prescriptions, all in one place',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Upload a prescription to get pharmacist support and manage refills securely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.mutedText,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploadPrescription,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Upload prescription'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const Search())),
                icon: const Icon(Icons.shopping_basket_outlined),
                label: const Text('Browse OTC & wellness'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 15, color: AppTheme.mutedText),
                SizedBox(width: 6),
                Text(
                  'Your documents are stored securely',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _uploadPrescription() async {
    final file = await showPrescriptionUploadSheet(context);
    if (!mounted || file == null) return;
    final uploadedRx = await Navigator.of(context).push<Prescription?>(
      MaterialPageRoute<Prescription?>(
        builder: (_) => PrescriptionReview(
          file: file,
          patientName: widget.patientName,
          patientId: widget.patientId,
          allergies: widget.allergies,
        ),
      ),
    );
    if (uploadedRx != null && mounted) {
      setState(() {
        _tab = 1;
      });
    }
  }

  void _reorderMeds(String? rxId) {
    if (rxId != null) {
      final cart = context.read<CartNotifier?>();
      cart?.attachPrescriptionId(rxId);
      AppToast.success(context, 'Prescription linked! Pharmacist will verify refills.');
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const Cart()),
      );
    } else {
      AppToast.info(context, 'Opening medicines catalog...');
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const Search()),
      );
    }
  }

  Widget _prescriptionCard({
    required String name,
    required String subtitle,
    required String date,
    required String status,
    String? rxId,
    PrescriptionStatus rxStatus = PrescriptionStatus.approved,
  }) {
    final isApproved = rxStatus == PrescriptionStatus.approved;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Rx mini ticket badge + Doctor Name + Verified Pill
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Rx',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryDark,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        date.split(' ').take(2).join(' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'For ${widget.patientName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isApproved ? const Color(0xFFE6F4EA) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isApproved ? const Color(0xFF065F46) : const Color(0xFF92400E),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Action row: 2 smart compact buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => _reorderMeds(rxId),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 15),
                    label: const Text('Reorder All Meds'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDocument(rxId, rxStatus),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View Slip'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _archivedView(List<Prescription> list) {
    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.history_edu_outlined,
                    color: AppTheme.textSecondary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No expired prescriptions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Past or expired prescriptions will appear here for your medical records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Past prescriptions',
              style: TextStyle(
                fontSize: 17,
                color: AppTheme.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            _pill(
              '${list.length} records',
              Colors.white,
              AppTheme.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...list.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _archiveCard(
              (p.doctorName != null && p.doctorName!.trim().isNotEmpty)
                  ? p.doctorName!.trim()
                  : (p.fileName.trim().isNotEmpty ? p.fileName.trim() : 'Uploaded Prescription'),
              'Prescription ${p.id.length > 8 ? p.id.substring(0, 8) : p.id}',
              'Expired on ${_formatDate(p.createdAt)}',
              p.fileName,
              'Archived prescription record',
              Colors.orange,
              rxId: p.id,
              status: p.status,
            ),
          ),
        ),
      ],
    );
  }

  Widget _archiveCard(
    String name,
    String subtitle,
    String expiry,
    String medicine,
    String detail,
    Color color, {
    String? rxId,
    PrescriptionStatus status = PrescriptionStatus.expired,
    bool first = false,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _iconTile(
              first ? Icons.badge_outlined : Icons.monitor_heart_outlined,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(expiry, color.withValues(alpha: .13), color),
            if (first) ...[
              _pill(
                'No refills left',
                const Color(0xFFFFE0DE),
                Colors.red.shade700,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF9FD),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    color: AppTheme.primary,
                    size: 17,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Prescribed medicines',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                medicine,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppTheme.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (first)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadPrescription,
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  label: const Text('Renew prescription'),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showDocument(rxId, status),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View document'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _tab = 0;
                      }),
                      icon: const Icon(Icons.unarchive_outlined, size: 18),
                      label: const Text('Restore'),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDocument(rxId, status),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View document'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadPrescription,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload new'),
                ),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _underReviewView(List<Prescription> list) {
    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: AppTheme.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nothing under review yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Upload a clear prescription and our pharmacy team will review it. You can follow its progress here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploadPrescription,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload prescription'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ...list.map(
          (p) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prescription submitted',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.fileName} · ${_formatDate(p.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _pill(
                      p.status.chipLabel.toUpperCase(),
                      AppTheme.infoBg,
                      AppTheme.infoText,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Most reviews are completed within 30–45 minutes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const PrescriptionProgressStep(
                  icon: Icons.check_rounded,
                  title: 'Prescription uploaded',
                  done: true,
                ),
                const PrescriptionProgressStep(
                  icon: Icons.medical_information_outlined,
                  title: 'Pharmacist review',
                  active: true,
                ),
                const PrescriptionProgressStep(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Medicines added to cart',
                ),
                const PrescriptionProgressStep(
                  icon: Icons.credit_card_outlined,
                  title: 'Ready for payment',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _showDocument(p.id, p.status),
                  icon: const Icon(Icons.manage_search_outlined, size: 17),
                  label: const Text('Manage & View Details'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFD9EDF2)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .025),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _iconTile(IconData icon, {double size = 44}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFDDF6FB),
      borderRadius: BorderRadius.circular(size == 48 ? size / 2 : 12),
    ),
    child: Icon(icon, color: AppTheme.primary, size: size * .48),
  );

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );

  void _showInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your Prescription Vault'),
      content: const Text(
        'Your prescriptions are stored securely and are only used to help pharmacists verify your medicines and refills.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  void _showDocument([
    String? rxId,
    PrescriptionStatus status = PrescriptionStatus.approved,
  ]) {
    final rxProvider = context.read<PrescriptionProvider?>();
    final rx = rxId != null
        ? rxProvider?.prescriptions.cast<Prescription?>().firstWhere(
            (p) => p?.id == rxId,
            orElse: () => null,
          )
        : null;

    final docName = rx?.doctorName ?? 'Prescribing Physician';
    final docSpecialty = rx != null
        ? 'Prescription ${rx.id.length > 8 ? rx.id.substring(0, 8) : rx.id}'
        : 'Clinical Prescription';

    showPrescriptionDetailSheet(
      context,
      prescriptionId: rxId,
      status: rx?.status ?? status,
      doctorName: docName,
      doctorSpecialty: docSpecialty,
      onArchive: () {
      if (rxId != null) {
        context.read<PrescriptionProvider?>()?.archivePrescription(rxId);
      }
      setState(() {
        _tab = 2;
      });
      AppToast.info(context, 'Prescription moved to Past & Expired.');
    },
    onDelete: () async {
      if (rxId != null) {
        final prov = context.read<PrescriptionProvider?>();
        final res = await prov?.deletePrescription(rxId);
        final success = res?.success ?? true;
        if (!mounted) return;
        final cart = context.read<CartNotifier?>();
        if (cart?.prescriptionId == rxId) {
          await cart?.removePrescriptionId();
        }
        if (!mounted) return;
        if (success) {
          AppToast.show(
            context,
            'Prescription deleted permanently.',
            icon: Icons.delete_sweep_rounded,
            iconColor: const Color(0xFFFCA5A5),
          );
        } else {
          AppToast.error(
            context,
            res?.message ?? 'Could not delete prescription from server.',
          );
        }
      }
    },
  );
  }
}
