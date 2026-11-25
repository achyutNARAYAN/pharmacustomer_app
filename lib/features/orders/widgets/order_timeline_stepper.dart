import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/order_model.dart';

/// Interactive Order Timeline Stepper based on MDP State Machine Doc Section 2
class OrderTimelineStepper extends StatelessWidget {
  final OrderStatus status;
  final List<OrderStatusHistory> statusHistory;
  final bool isCompact;
  final String? rejectionReason;
  final String? cancellationReason;

  const OrderTimelineStepper({
    super.key,
    required this.status,
    this.statusHistory = const [],
    this.isCompact = false,
    this.rejectionReason,
    this.cancellationReason,
  });

  static const List<Map<String, dynamic>> _steps = [
    {
      'step': 1,
      'status': OrderStatus.ORDER_PLACED,
      'title': 'Order Confirmed',
      'subtitle': 'Order placed & pushed to chemist queue',
      'icon': Icons.receipt_long_rounded,
    },
    {
      'step': 2,
      'status': OrderStatus.STORE_ACCEPTED,
      'title': 'Pharmacy Accepted',
      'subtitle': 'Verified inventory within 15-min SLA',
      'icon': Icons.storefront_rounded,
    },
    {
      'step': 3,
      'status': OrderStatus.PACKING,
      'title': 'Packing Medicines',
      'subtitle': 'Chemist is picking batches & sealing package',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'step': 4,
      'status': OrderStatus.READY_FOR_PICKUP,
      'title': 'Ready for Pickup',
      'subtitle': 'Package sealed, waiting for delivery partner',
      'icon': Icons.shopping_bag_outlined,
    },
    {
      'step': 5,
      'status': OrderStatus.DRIVER_ASSIGNED,
      'title': 'Rider Assigned',
      'subtitle': 'Delivery partner heading to pharmacy',
      'icon': Icons.person_pin_circle_rounded,
    },
    {
      'step': 6,
      'status': OrderStatus.OUT_FOR_DELIVERY,
      'title': 'Out for Delivery',
      'subtitle': 'Rider on the way with your package',
      'icon': Icons.moped_rounded,
    },
    {
      'step': 7,
      'status': OrderStatus.DELIVERED,
      'title': 'Delivered 🎉',
      'subtitle': 'Handover completed successfully',
      'icon': Icons.check_circle_rounded,
    },
  ];

  DateTime? _findTimeForStatus(OrderStatus target) {
    try {
      final entry = statusHistory.firstWhere(
        (h) => h.status == target,
      );
      return entry.changedAt;
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactStepper();
    }
    return _buildFullStepper();
  }

  /// Compact Horizontal Step Bar (ideal for Cards & Overview)
  Widget _buildCompactStepper() {
    final currentStep = status.timelineStep;
    final isTerminal = status.isTerminal;

    if (isTerminal) {
      return _buildTerminalBanner();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_steps.length, (index) {
            final stepIndex = index + 1;
            final isDone = currentStep >= stepIndex;
            final isCurrent = currentStep == stepIndex;

            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.primary
                            : (isCurrent ? AppTheme.primaryDark : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (index < _steps.length - 1) const SizedBox(width: 3),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          status.timelineStepLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
      ],
    );
  }

  /// Full Detailed Vertical Stepper
  Widget _buildFullStepper() {
    final currentStep = status.timelineStep;
    final isTerminal = status.isTerminal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isTerminal) ...[
          _buildTerminalBanner(),
          const SizedBox(height: 16),
        ],

        // Stepper Title
        Row(
          children: [
            const Icon(Icons.timeline_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Live Order Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isTerminal ? Colors.red.shade50 : AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.displayTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isTerminal ? Colors.red.shade700 : AppTheme.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Steps List
        ...List.generate(_steps.length, (index) {
          final item = _steps[index];
          final stepNum = item['step'] as int;
          final stepStatus = item['status'] as OrderStatus;
          final title = item['title'] as String;
          final subtitle = item['subtitle'] as String;
          final isLast = index == _steps.length - 1;

          final isDone = !isTerminal && currentStep > stepNum;
          final isCurrent = !isTerminal && currentStep == stepNum;

          final time = _findTimeForStatus(stepStatus);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator Line & Icon
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppTheme.primary
                          : (isCurrent
                              ? const Color(0xFFE0F2F1)
                              : Colors.grey.shade100),
                      border: Border.all(
                        color: isDone
                            ? AppTheme.primary
                            : (isCurrent
                                ? AppTheme.primary
                                : Colors.grey.shade300),
                        width: isCurrent ? 2.5 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : isCurrent
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : Text(
                                  '$stepNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 38,
                      color: isDone ? AppTheme.primary : Colors.grey.shade200,
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Step Details Text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : (isDone ? FontWeight.w600 : FontWeight.normal),
                                color: isCurrent
                                    ? AppTheme.primaryDark
                                    : (isDone ? AppTheme.text : AppTheme.mutedText),
                              ),
                            ),
                          ),
                          if (time != null)
                            Text(
                              _formatTime(time),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: isCurrent
                              ? AppTheme.textSecondary
                              : (isDone ? AppTheme.mutedText : Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Terminal State Alert Banner (Cancelled, Rejected, Failed, Refunded)
  Widget _buildTerminalBanner() {
    final (color, icon, title, message) = switch (status) {
      OrderStatus.CANCELLED => (
          Colors.red,
          Icons.cancel_rounded,
          'Order Cancelled',
          cancellationReason != null && cancellationReason!.isNotEmpty
              ? cancellationReason!
              : 'This order has been cancelled by customer request.',
        ),
      OrderStatus.STORE_REJECTED => (
          Colors.amber.shade900,
          Icons.error_outline_rounded,
          'Pharmacy Unavailable',
          rejectionReason != null && rejectionReason!.isNotEmpty
              ? rejectionReason!
              : 'Pharmacy could not fulfill inventory. Auto-refund initiated.',
        ),
      OrderStatus.DELIVERY_FAILED => (
          Colors.red,
          Icons.wrong_location_rounded,
          'Delivery Failed',
          'Rider could not reach destination. Our support team will assist.',
        ),
      OrderStatus.REFUNDED => (
          const Color(0xFF16A34A),
          Icons.currency_rupee_rounded,
          'Payment Refunded',
          'Full order amount has been refunded back to original source account.',
        ),
      _ => (
          Colors.grey,
          Icons.info_outline_rounded,
          status.displayTitle,
          '',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
