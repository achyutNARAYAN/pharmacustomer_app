import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Shows a customer-first, attractive 24x7 support modal sheet matching the app's brand theme.
///
/// Automatically formats WhatsApp and dialer queries with pre-filled context
/// if [orderId] or [prescriptionId] is provided.
Future<void> showCustomerSupportSheet(
  BuildContext context, {
  String? orderId,
  String? prescriptionId,
  String? customQuery,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _CustomerSupportModal(
      orderId: orderId,
      prescriptionId: prescriptionId,
      customQuery: customQuery,
    ),
  );
}

class _CustomerSupportModal extends StatefulWidget {
  final String? orderId;
  final String? prescriptionId;
  final String? customQuery;

  const _CustomerSupportModal({
    this.orderId,
    this.prescriptionId,
    this.customQuery,
  });

  @override
  State<_CustomerSupportModal> createState() => _CustomerSupportModalState();
}

class _CustomerSupportModalState extends State<_CustomerSupportModal> {
  // Support Contact Configuration
  static const String _whatsappNumber = '919876543210';
  static const String _tollFreePhone = '18001234567';
  static const String _displayTollFree = '1800-123-4567';
  static const String _supportEmail = 'support@pharmacustomer.com';

  int? _expandedFaqIndex;

  final List<Map<String, dynamic>> _faqs = const [
    {
      'icon': Icons.local_shipping_outlined,
      'q': 'Where is my order right now?',
      'a': 'Orders are packed and dispatched from our local hub within 15–30 minutes. You can track real-time delivery status using the "Track order" button on your order card.',
    },
    {
      'icon': Icons.verified_user_outlined,
      'q': 'How does prescription verification work?',
      'a': 'Our licensed pharmacists review every uploaded prescription for dosage and doctor authenticity within 20–30 minutes before packing your medicines.',
    },
    {
      'icon': Icons.currency_rupee_rounded,
      'q': 'Can I cancel or get a refund?',
      'a': 'Yes, you can cancel any order before dispatch for an immediate 100% refund credited directly back to your original payment method.',
    },
    {
      'icon': Icons.health_and_safety_outlined,
      'q': 'Are all medicines 100% authentic?',
      'a': 'Yes, 100%. All medicines are sourced directly from licensed pharma manufacturers with verifiable batch numbers and tamper-proof packaging.',
    },
  ];

  String _buildPreFilledText() {
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      return 'Hi PharmaCustomer Support, I need help with my Order #${widget.orderId}.';
    }
    if (widget.prescriptionId != null && widget.prescriptionId!.isNotEmpty) {
      return 'Hi PharmaCustomer Pharmacist, I have a query about my Prescription #${widget.prescriptionId}.';
    }
    if (widget.customQuery != null && widget.customQuery!.isNotEmpty) {
      return widget.customQuery!;
    }
    return 'Hi PharmaCustomer Support, I need assistance with my medicine order.';
  }

  Future<void> _openWhatsApp() async {
    final text = Uri.encodeComponent(_buildPreFilledText());
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$text');

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _fallbackCopy('WhatsApp support number copied: +$_whatsappNumber');
      }
    } catch (_) {
      if (mounted) {
        _fallbackCopy('Support WhatsApp: +$_whatsappNumber');
      }
    }
  }

  Future<void> _callSupport() async {
    final url = Uri.parse('tel:$_tollFreePhone');
    try {
      final launched = await launchUrl(url);
      if (!launched && mounted) {
        _fallbackCopy('Toll-Free Phone: $_displayTollFree');
      }
    } catch (_) {
      if (mounted) {
        _fallbackCopy('Toll-Free Phone: $_displayTollFree');
      }
    }
  }

  Future<void> _sendEmail() async {
    final subject = Uri.encodeComponent(
      widget.orderId != null
          ? 'Support Request - Order #${widget.orderId}'
          : 'PharmaCustomer Support Request',
    );
    final body = Uri.encodeComponent(_buildPreFilledText());
    final url = Uri.parse('mailto:$_supportEmail?subject=$subject&body=$body');

    try {
      final launched = await launchUrl(url);
      if (!launched && mounted) {
        _fallbackCopy('Support Email: $_supportEmail');
      }
    } catch (_) {
      if (mounted) {
        _fallbackCopy('Support Email: $_supportEmail');
      }
    }
  }

  void _fallbackCopy(String message) {
    Clipboard.setData(const ClipboardData(text: _displayTollFree));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Matching App Theme Colors) ────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '24x7 Customer Care',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Context Order / Rx Banner ─────────────────────────────────
              if (widget.orderId != null && widget.orderId!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC7EBF2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regarding Order #${widget.orderId}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            const Text(
                              'Order details will be shared automatically',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (widget.prescriptionId != null && widget.prescriptionId!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC7EBF2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medication_outlined,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regarding Prescription #${widget.prescriptionId}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            const Text(
                              'Pharmacist will review your Rx query',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Action 1: WhatsApp (App Palette) ──────────────────────────
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _openWhatsApp();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC7EBF2), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Chat on WhatsApp',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Instant reply on order support',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppTheme.surfaceLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Action 2: Call Helpline (App Palette) ─────────────────────
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _callSupport();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.outlineBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Call Toll-Free Number',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '$_displayTollFree • 8 AM – 11 PM',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppTheme.surfaceLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── FAQs Section (App Palette) ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: AppTheme.text,
                    ),
                  ),
                  Text(
                    'Instant answers',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ...List.generate(_faqs.length, (index) {
                final faq = _faqs[index];
                final isExpanded = _expandedFaqIndex == index;
                final icon = faq['icon'] as IconData;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isExpanded ? AppTheme.primaryContainer.withValues(alpha: 0.3) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExpanded
                          ? AppTheme.primary
                          : AppTheme.outlineBorder,
                      width: isExpanded ? 1.4 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key('faq_$index'),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (val) {
                        setState(() {
                          _expandedFaqIndex = val ? index : null;
                        });
                      },
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppTheme.primary, size: 18),
                      ),
                      title: Text(
                        faq['q'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? AppTheme.primaryDark : AppTheme.text,
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.outlineBorder),
                          ),
                          child: Text(
                            faq['a'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 14),

              // ── Footer: Clean Email Support Option ────────────────────────
              Center(
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _sendEmail();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mail_outline_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 7),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            children: [
                              TextSpan(text: 'Need formal assistance? '),
                              TextSpan(
                                text: 'Email Support',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
