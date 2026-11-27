// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';

/// Exact Order Status matching MDP Backend State Machine
enum OrderStatus {
  PAYMENT_PENDING,
  ORDER_PLACED,
  STORE_ACCEPTED,
  PACKING,
  READY_FOR_PICKUP,
  DRIVER_ASSIGNED,
  OUT_FOR_DELIVERY,
  DELIVERED,
  CANCELLED,
  STORE_REJECTED,
  DELIVERY_FAILED,
  REFUNDED;

  static OrderStatus fromString(String? status) {
    if (status == null || status.isEmpty) return OrderStatus.ORDER_PLACED;
    final normalized = status
        .toUpperCase()
        .trim()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return OrderStatus.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () {
        // Fallback mapping for legacy/alternate backend status names
        switch (normalized) {
          case 'PLACED':
          case 'ORDER_PLACED':
            return OrderStatus.ORDER_PLACED;
          case 'CONFIRMED':
          case 'ACCEPTED':
          case 'STORE_ACCEPTED':
          case 'STOREACCEPTED':
          case 'ACCEPTED_BY_STORE':
          case 'STORE_CONFIRMED':
          case 'PHARMACY_ACCEPTED':
          case 'ACCEPTED_BY_PHARMACY':
          case 'PHARMACY_CONFIRMED':
          case 'VERIFIED':
          case 'APPROVED':
            return OrderStatus.STORE_ACCEPTED;
          case 'PROCESSING':
          case 'PACKING':
          case 'PACKED':
          case 'PREPARING':
          case 'DISPENSING':
          case 'PACKING_STARTED':
            return OrderStatus.PACKING;
          case 'READY_FOR_PICKUP':
          case 'READY':
            return OrderStatus.READY_FOR_PICKUP;
          case 'DRIVER_ASSIGNED':
          case 'RIDER_ASSIGNED':
          case 'ASSIGNED':
            return OrderStatus.DRIVER_ASSIGNED;
          case 'OUT_FOR_DELIVERY':
          case 'OUTFORDELIVERY':
          case 'DISPATCHED':
          case 'IN_TRANSIT':
            return OrderStatus.OUT_FOR_DELIVERY;
          case 'DELIVERED':
          case 'COMPLETED':
            return OrderStatus.DELIVERED;
          case 'CANCELLED':
          case 'CANCELED':
            return OrderStatus.CANCELLED;
          case 'REJECTED':
          case 'STORE_REJECTED':
          case 'DECLINED':
            return OrderStatus.STORE_REJECTED;
          case 'FAILED':
          case 'DELIVERY_FAILED':
            return OrderStatus.DELIVERY_FAILED;
          case 'REFUNDED':
            return OrderStatus.REFUNDED;
          default:
            return OrderStatus.ORDER_PLACED;
        }
      },
    );
  }

  /// Customer can cancel only in early states (before packing starts)
  bool get canCustomerCancel =>
      this == OrderStatus.PAYMENT_PENDING ||
      this == OrderStatus.ORDER_PLACED ||
      this == OrderStatus.STORE_ACCEPTED;

  /// Whether customer should show delivery OTP to rider
  bool get showDeliveryOtp => this == OrderStatus.OUT_FOR_DELIVERY;

  /// Order is active / in progress
  bool get isActive =>
      this != OrderStatus.DELIVERED &&
      this != OrderStatus.CANCELLED &&
      this != OrderStatus.STORE_REJECTED &&
      this != OrderStatus.DELIVERY_FAILED &&
      this != OrderStatus.REFUNDED;

  String get displayTitle {
    switch (this) {
      case OrderStatus.PAYMENT_PENDING:
        return 'Payment Pending';
      case OrderStatus.ORDER_PLACED:
        return 'Order Placed';
      case OrderStatus.STORE_ACCEPTED:
        return 'Chemist Verified';
      case OrderStatus.PACKING:
        return 'Packing Medicines';
      case OrderStatus.READY_FOR_PICKUP:
        return 'Ready for Pickup';
      case OrderStatus.DRIVER_ASSIGNED:
        return 'Rider Assigned';
      case OrderStatus.OUT_FOR_DELIVERY:
        return 'Out for Express Delivery';
      case OrderStatus.DELIVERED:
        return 'Delivered Successfully 🎉';
      case OrderStatus.CANCELLED:
        return 'Order Cancelled';
      case OrderStatus.STORE_REJECTED:
        return 'Store Unavailable (Refund Initiated)';
      case OrderStatus.DELIVERY_FAILED:
        return 'Delivery Failed';
      case OrderStatus.REFUNDED:
        return 'Amount Refunded';
    }
  }

  /// Numerical Timeline Step (0 through 7) as defined in MDP Doc Section 2
  int get timelineStep {
    switch (this) {
      case OrderStatus.PAYMENT_PENDING:
        return 0;
      case OrderStatus.ORDER_PLACED:
        return 1;
      case OrderStatus.STORE_ACCEPTED:
        return 2;
      case OrderStatus.PACKING:
        return 3;
      case OrderStatus.READY_FOR_PICKUP:
        return 4;
      case OrderStatus.DRIVER_ASSIGNED:
        return 5;
      case OrderStatus.OUT_FOR_DELIVERY:
        return 6;
      case OrderStatus.DELIVERED:
        return 7;
      case OrderStatus.CANCELLED:
      case OrderStatus.STORE_REJECTED:
      case OrderStatus.DELIVERY_FAILED:
      case OrderStatus.REFUNDED:
        return -1; // Terminal state
    }
  }

  /// Official UI Timeline Step Label from MDP Documentation Table
  String get timelineStepLabel {
    switch (this) {
      case OrderStatus.PAYMENT_PENDING:
        return 'Step 0: Payment Incomplete';
      case OrderStatus.ORDER_PLACED:
        return 'Step 1: Order Confirmed';
      case OrderStatus.STORE_ACCEPTED:
        return 'Step 2: Pharmacy Accepted';
      case OrderStatus.PACKING:
        return 'Step 3: Packing Medicines';
      case OrderStatus.READY_FOR_PICKUP:
        return 'Step 4: Ready for Pickup';
      case OrderStatus.DRIVER_ASSIGNED:
        return 'Step 5: Rider Assigned';
      case OrderStatus.OUT_FOR_DELIVERY:
        return 'Step 6: Out for Delivery';
      case OrderStatus.DELIVERED:
        return 'Step 7: Delivered 🎉';
      case OrderStatus.CANCELLED:
        return 'Order Cancelled';
      case OrderStatus.STORE_REJECTED:
        return 'Pharmacy Declined';
      case OrderStatus.DELIVERY_FAILED:
        return 'Delivery Failed';
      case OrderStatus.REFUNDED:
        return 'Payment Refunded';
    }
  }

  bool get isTerminal =>
      this == OrderStatus.CANCELLED ||
      this == OrderStatus.STORE_REJECTED ||
      this == OrderStatus.DELIVERY_FAILED ||
      this == OrderStatus.REFUNDED;
}

/// Status Timeline Item
@immutable
class OrderStatusHistory {
  final OrderStatus status;
  final DateTime? changedAt;
  final String? note;
  final String? actorType;

  const OrderStatusHistory({
    required this.status,
    this.changedAt,
    this.note,
    this.actorType,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      status: OrderStatus.fromString(json['status']?.toString()),
      changedAt: json['changedAt'] != null
          ? DateTime.tryParse(json['changedAt'].toString())
          : null,
      note: json['note']?.toString(),
      actorType: json['actorType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        if (changedAt != null) 'changedAt': changedAt!.toUtc().toIso8601String(),
        if (note != null) 'note': note,
        if (actorType != null) 'actorType': actorType,
      };
}

/// Order Line Item Model
@immutable
class OrderItemModel {
  final String medicineId;
  final String name;
  final int quantity;
  final int pricePaise;
  final int mrpPaise;
  final int lineTotalPaise;
  final bool isPrescriptionRequired;
  final String pack;

  const OrderItemModel({
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.pricePaise,
    required this.mrpPaise,
    required this.lineTotalPaise,
    required this.isPrescriptionRequired,
    this.pack = '1 Unit',
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final med = json['medicine'];
    final medId = med is Map ? (med['_id']?.toString() ?? '') : (med?.toString() ?? json['id']?.toString() ?? '');
    final name = json['name']?.toString() ?? (med is Map ? med['name']?.toString() : null) ?? 'Medicine';
    final qty = (json['quantity'] as num?)?.toInt() ?? 1;
    final pricePaise = (json['pricePaise'] as num?)?.toInt() ??
        (((json['price'] as num?)?.toDouble() ?? 0.0) * 100).round();
    final mrpPaise = (json['mrpPaise'] as num?)?.toInt() ?? pricePaise;
    final lineTotalPaise = (json['lineTotalPaise'] as num?)?.toInt() ?? (pricePaise * qty);
    final isRx = json['isPrescriptionRequired'] == true || json['requiresPrescription'] == true;
    final pack = json['pack']?.toString() ?? '1 Unit';

    return OrderItemModel(
      medicineId: medId,
      name: name,
      quantity: qty,
      pricePaise: pricePaise,
      mrpPaise: mrpPaise,
      lineTotalPaise: lineTotalPaise,
      isPrescriptionRequired: isRx,
      pack: pack,
    );
  }

  Map<String, dynamic> toJson() => {
        'medicine': medicineId,
        'name': name,
        'quantity': quantity,
        'pricePaise': pricePaise,
        'mrpPaise': mrpPaise,
        'lineTotalPaise': lineTotalPaise,
        'isPrescriptionRequired': isPrescriptionRequired,
        'pack': pack,
      };

  String get formattedPrice => '₹${(pricePaise / 100).toStringAsFixed(2)}';
  String get formattedTotal => '₹${(lineTotalPaise / 100).toStringAsFixed(2)}';
  double get price => pricePaise / 100.0;
  double get total => lineTotalPaise / 100.0;
  String get id => medicineId;
  bool get requiresPrescription => isPrescriptionRequired;
}

/// Full Canonical Order Model
@immutable
class OrderModel {
  final String id;
  final String orderCode;
  final OrderStatus status;
  final String paymentMethod;
  final String paymentStatus;
  final int itemsTotalPaise;
  final int deliveryFeePaise;
  final int discountPaise;
  final int taxPaise;
  final int totalPayablePaise;
  final String? deliveryOtp;
  final String? customerNote;
  final String? storeName;
  final String? storeAddress;
  final String? deliveryAddressText;
  final String? contactName;
  final String? contactMobile;
  final List<double>? deliveryCoordinates; // [lng, lat]
  final List<double>? pickupCoordinates;   // [lng, lat]
  final List<OrderItemModel> items;
  final List<OrderStatusHistory> statusHistory;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? storeAcceptanceDeadlineAt;
  final DateTime? storeAcceptedAt;
  final DateTime? packedAt;
  final DateTime? dispatchedAt;
  final int? pollIntervalSeconds;
  final String? rejectionReason;
  final String? cancellationReason;

  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.itemsTotalPaise,
    required this.deliveryFeePaise,
    required this.discountPaise,
    this.taxPaise = 0,
    required this.totalPayablePaise,
    this.deliveryOtp,
    this.customerNote,
    this.storeName,
    this.storeAddress,
    this.deliveryAddressText,
    this.contactName,
    this.contactMobile,
    this.deliveryCoordinates,
    this.pickupCoordinates,
    required this.items,
    this.statusHistory = const [],
    required this.createdAt,
    this.deliveredAt,
    this.cancelledAt,
    this.storeAcceptanceDeadlineAt,
    this.storeAcceptedAt,
    this.packedAt,
    this.dispatchedAt,
    this.pollIntervalSeconds,
    this.rejectionReason,
    this.cancellationReason,
  });

  /// Primary ID accessor
  String get orderId => orderCode.isNotEmpty ? orderCode : id;
  bool get isActive => status.isActive;
  bool get canCancel => status.canCustomerCancel;
  bool get isPollingActive => status.isActive;
  bool get isStoreAccepted =>
      storeAcceptedAt != null ||
      status == OrderStatus.STORE_ACCEPTED ||
      status == OrderStatus.PACKING ||
      status == OrderStatus.READY_FOR_PICKUP ||
      status == OrderStatus.DRIVER_ASSIGNED ||
      status == OrderStatus.OUT_FOR_DELIVERY ||
      status == OrderStatus.DELIVERED;
  int get itemCount => items.fold<int>(0, (sum, i) => sum + i.quantity);
  int get totalPaise => totalPayablePaise;
  String get formattedTotal => '₹${(totalPayablePaise / 100).toStringAsFixed(2)}';

  OrderModel copyWith({
    String? id,
    String? orderCode,
    OrderStatus? status,
    String? paymentMethod,
    String? paymentStatus,
    int? itemsTotalPaise,
    int? deliveryFeePaise,
    int? discountPaise,
    int? taxPaise,
    int? totalPayablePaise,
    String? deliveryOtp,
    String? customerNote,
    String? storeName,
    String? storeAddress,
    String? deliveryAddressText,
    String? contactName,
    String? contactMobile,
    List<double>? deliveryCoordinates,
    List<double>? pickupCoordinates,
    List<OrderItemModel>? items,
    List<OrderStatusHistory>? statusHistory,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? storeAcceptanceDeadlineAt,
    DateTime? storeAcceptedAt,
    DateTime? packedAt,
    DateTime? dispatchedAt,
    int? pollIntervalSeconds,
    String? rejectionReason,
    String? cancellationReason,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      itemsTotalPaise: itemsTotalPaise ?? this.itemsTotalPaise,
      deliveryFeePaise: deliveryFeePaise ?? this.deliveryFeePaise,
      discountPaise: discountPaise ?? this.discountPaise,
      taxPaise: taxPaise ?? this.taxPaise,
      totalPayablePaise: totalPayablePaise ?? this.totalPayablePaise,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
      customerNote: customerNote ?? this.customerNote,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      deliveryAddressText: deliveryAddressText ?? this.deliveryAddressText,
      contactName: contactName ?? this.contactName,
      contactMobile: contactMobile ?? this.contactMobile,
      deliveryCoordinates: deliveryCoordinates ?? this.deliveryCoordinates,
      pickupCoordinates: pickupCoordinates ?? this.pickupCoordinates,
      items: items ?? this.items,
      statusHistory: statusHistory ?? this.statusHistory,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      storeAcceptanceDeadlineAt: storeAcceptanceDeadlineAt ?? this.storeAcceptanceDeadlineAt,
      storeAcceptedAt: storeAcceptedAt ?? this.storeAcceptedAt,
      packedAt: packedAt ?? this.packedAt,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> rawJson) {
    final json = rawJson['order'] is Map<String, dynamic>
        ? <String, dynamic>{
            ...rawJson,
            ...(rawJson['order'] as Map<String, dynamic>),
          }
        : rawJson;

    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final orderCode = json['orderCode']?.toString() ?? json['orderId']?.toString() ?? id;
    final status = OrderStatus.fromString(json['status']?.toString());
    final paymentMethod = json['paymentMethod']?.toString() ?? 'ONLINE';
    final paymentStatus = json['paymentStatus']?.toString() ?? 'PAID';

    final itemsTotalPaise = (json['itemsTotalPaise'] as num?)?.toInt() ?? 0;
    final deliveryFeePaise = (json['deliveryFeePaise'] as num?)?.toInt() ?? 0;
    final discountPaise = (json['discountPaise'] as num?)?.toInt() ?? 0;
    final taxPaise = (json['taxPaise'] as num?)?.toInt() ?? 0;
    final totalPayablePaise = (json['totalPayablePaise'] as num?)?.toInt() ??
        (json['totalPaise'] as num?)?.toInt() ??
        (itemsTotalPaise + deliveryFeePaise - discountPaise + taxPaise);

    final deliveryOtp = json['deliveryOtp']?.toString();
    final customerNote = json['customerNote']?.toString();

    // Store extraction
    String? storeName;
    String? storeAddress;
    List<double>? pickupCoords;
    if (json['store'] is Map<String, dynamic>) {
      final s = json['store'] as Map<String, dynamic>;
      storeName = s['name']?.toString();
      storeAddress = s['address']?.toString();
    }
    if (json['pickupAddress'] is Map<String, dynamic>) {
      final p = json['pickupAddress'] as Map<String, dynamic>;
      storeName ??= p['storeName']?.toString();
      storeAddress ??= [p['addressLine1'], p['locality'], p['city']].whereType<String>().where((str) => str.isNotEmpty).join(', ');
      if (p['location'] is Map && (p['location'] as Map)['coordinates'] is List) {
        final coords = (p['location'] as Map)['coordinates'] as List;
        if (coords.length >= 2) {
          pickupCoords = [(coords[0] as num).toDouble(), (coords[1] as num).toDouble()];
        }
      }
    }

    // Delivery address extraction
    String? deliveryAddressText;
    String? contactName;
    String? contactMobile;
    List<double>? deliveryCoords;
    if (json['deliveryAddress'] is Map<String, dynamic>) {
      final d = json['deliveryAddress'] as Map<String, dynamic>;
      contactName = d['contactName']?.toString();
      contactMobile = d['contactMobile']?.toString();
      deliveryAddressText = [
        d['addressLine1'],
        d['addressLine2'],
        d['landmark'],
        d['city'],
        d['pinCode'],
      ].whereType<String>().where((str) => str.isNotEmpty).join(', ');

      if (d['location'] is Map && (d['location'] as Map)['coordinates'] is List) {
        final coords = (d['location'] as Map)['coordinates'] as List;
        if (coords.length >= 2) {
          deliveryCoords = [(coords[0] as num).toDouble(), (coords[1] as num).toDouble()];
        }
      }
    }

    // Items extraction
    final rawItems = json['items'];
    final items = <OrderItemModel>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(OrderItemModel.fromJson(item));
        }
      }
    }

    // Status history extraction
    final rawHistory = json['statusHistory'];
    final history = <OrderStatusHistory>[];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is Map<String, dynamic>) {
          history.add(OrderStatusHistory.fromJson(h));
        }
      }
    }

    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final deliveredAt = json['deliveredAt'] != null
        ? DateTime.tryParse(json['deliveredAt'].toString())
        : null;
    final cancelledAt = json['cancelledAt'] != null
        ? DateTime.tryParse(json['cancelledAt'].toString())
        : null;
    final storeAcceptanceDeadlineAt = json['storeAcceptanceDeadlineAt'] != null
        ? DateTime.tryParse(json['storeAcceptanceDeadlineAt'].toString())
        : null;
    final rawAcceptedAt = json['storeAcceptedAt'] ??
        json['acceptedAt'] ??
        json['pharmacyAcceptedAt'];
    DateTime? storeAcceptedAt = rawAcceptedAt != null
        ? DateTime.tryParse(rawAcceptedAt.toString())
        : null;
    if (storeAcceptedAt == null) {
      for (final h in history) {
        if (h.status == OrderStatus.STORE_ACCEPTED ||
            h.status == OrderStatus.PACKING ||
            h.status == OrderStatus.READY_FOR_PICKUP ||
            h.status == OrderStatus.DRIVER_ASSIGNED ||
            h.status == OrderStatus.OUT_FOR_DELIVERY ||
            h.status == OrderStatus.DELIVERED) {
          storeAcceptedAt = h.changedAt ?? createdAt;
          break;
        }
      }
    }
    final packedAt = json['packedAt'] != null
        ? DateTime.tryParse(json['packedAt'].toString())
        : null;
    final dispatchedAt = json['dispatchedAt'] != null
        ? DateTime.tryParse(json['dispatchedAt'].toString())
        : null;
    final pollIntervalSeconds = (json['pollIntervalSeconds'] as num?)?.toInt();
    final rejectionReason = json['rejectionReason']?.toString();
    final cancellationReason = json['cancellationReason']?.toString();

    return OrderModel(
      id: id,
      orderCode: orderCode,
      status: status,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      itemsTotalPaise: itemsTotalPaise,
      deliveryFeePaise: deliveryFeePaise,
      discountPaise: discountPaise,
      taxPaise: taxPaise,
      totalPayablePaise: totalPayablePaise,
      deliveryOtp: deliveryOtp,
      customerNote: customerNote,
      storeName: storeName,
      storeAddress: storeAddress,
      deliveryAddressText: deliveryAddressText,
      contactName: contactName,
      contactMobile: contactMobile,
      deliveryCoordinates: deliveryCoords,
      pickupCoordinates: pickupCoords,
      items: items,
      statusHistory: history,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      cancelledAt: cancelledAt,
      storeAcceptanceDeadlineAt: storeAcceptanceDeadlineAt,
      storeAcceptedAt: storeAcceptedAt,
      packedAt: packedAt,
      dispatchedAt: dispatchedAt,
      pollIntervalSeconds: pollIntervalSeconds,
      rejectionReason: rejectionReason,
      cancellationReason: cancellationReason,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'orderCode': orderCode,
        'status': status.name,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'itemsTotalPaise': itemsTotalPaise,
        'deliveryFeePaise': deliveryFeePaise,
        'discountPaise': discountPaise,
        'taxPaise': taxPaise,
        'totalPayablePaise': totalPayablePaise,
        if (deliveryOtp != null) 'deliveryOtp': deliveryOtp,
        if (customerNote != null) 'customerNote': customerNote,
        if (storeName != null) 'store': {'name': storeName, 'address': storeAddress},
        if (deliveryAddressText != null)
          'deliveryAddress': {
            'addressLine1': deliveryAddressText,
            'contactName': contactName,
            'contactMobile': contactMobile,
          },
        'items': items.map((i) => i.toJson()).toList(),
        'statusHistory': statusHistory.map((h) => h.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toUtc().toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toUtc().toIso8601String(),
        if (storeAcceptanceDeadlineAt != null)
          'storeAcceptanceDeadlineAt': storeAcceptanceDeadlineAt!.toUtc().toIso8601String(),
        if (storeAcceptedAt != null)
          'storeAcceptedAt': storeAcceptedAt!.toUtc().toIso8601String(),
        if (packedAt != null)
          'packedAt': packedAt!.toUtc().toIso8601String(),
        if (dispatchedAt != null)
          'dispatchedAt': dispatchedAt!.toUtc().toIso8601String(),
        if (pollIntervalSeconds != null) 'pollIntervalSeconds': pollIntervalSeconds,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (cancellationReason != null) 'cancellationReason': cancellationReason,
      };
}

/// Backwards compatibility alias
typedef OrderItem = OrderModel;
