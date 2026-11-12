import '../../../core/models/cart_item.dart';

/// Single line item inside the MDP active/locked cart.
class CartLineItem {
  final String id; // Cart line item MongoDB ObjectId (_id)
  final String medicineId; // Catalog medicine ID
  final String name;
  final int quantity;
  final int pricePaise; // Whole integer paise (1 INR = 100 paise)
  final int mrpPaise;
  final bool isPrescriptionRequired;
  final String packSize;
  final String? brand;
  final String? batchNumber;

  const CartLineItem({
    required this.id,
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.pricePaise,
    required this.mrpPaise,
    this.isPrescriptionRequired = false,
    this.packSize = '',
    this.brand,
    this.batchNumber,
  });

  int get lineTotalPaise => pricePaise * quantity;
  double get priceInRupees => pricePaise / 100.0;
  double get lineTotalInRupees => lineTotalPaise / 100.0;

  String get formattedPrice {
    final rupees = pricePaise / 100.0;
    return '₹${pricePaise % 100 == 0 ? rupees.toStringAsFixed(0) : rupees.toStringAsFixed(2)}';
  }

  String get formattedLineTotal {
    final rupees = lineTotalPaise / 100.0;
    return '₹${lineTotalPaise % 100 == 0 ? rupees.toStringAsFixed(0) : rupees.toStringAsFixed(2)}';
  }

  CartLineItem copyWith({
    String? id,
    String? medicineId,
    String? name,
    int? quantity,
    int? pricePaise,
    int? mrpPaise,
    bool? isPrescriptionRequired,
    String? packSize,
    String? brand,
    String? batchNumber,
  }) {
    return CartLineItem(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      pricePaise: pricePaise ?? this.pricePaise,
      mrpPaise: mrpPaise ?? this.mrpPaise,
      isPrescriptionRequired: isPrescriptionRequired ?? this.isPrescriptionRequired,
      packSize: packSize ?? this.packSize,
      brand: brand ?? this.brand,
      batchNumber: batchNumber ?? this.batchNumber,
    );
  }

  /// Converts to legacy CartItem for compatibility with existing UI widgets.
  CartItem toCartItem() {
    return CartItem(
      id: id,
      name: name,
      pack: packSize.isNotEmpty ? packSize : '1 Unit',
      price: priceInRupees,
      quantity: quantity,
      requiresPrescription: isPrescriptionRequired,
    );
  }

  factory CartLineItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['_id'] as String? ?? json['id'] as String? ?? '';
    final rawMed = json['medicine'];
    String medId = '';
    String pack = '';
    String? brand;

    if (rawMed is Map<String, dynamic>) {
      medId = rawMed['_id'] as String? ?? rawMed['id'] as String? ?? '';
      pack = rawMed['packSize'] as String? ?? '';
      brand = rawMed['brand'] as String?;
    } else if (rawMed is String) {
      medId = rawMed;
    }

    if (medId.isEmpty) {
      medId = json['medicineId'] as String? ?? rawId;
    }

    final price = (json['pricePaise'] as num?)?.toInt() ??
        ((json['price'] as num?) != null ? ((json['price'] as num) * 100).round() : 0);
    final mrp = (json['mrpPaise'] as num?)?.toInt() ?? price;
    final qty = (json['quantity'] as num?)?.toInt() ?? 1;

    return CartLineItem(
      id: rawId,
      medicineId: medId,
      name: json['name'] as String? ?? '',
      quantity: qty.clamp(1, 50),
      pricePaise: price,
      mrpPaise: mrp,
      isPrescriptionRequired: json['isPrescriptionRequired'] == true,
      packSize: pack.isNotEmpty ? pack : (json['packSize'] as String? ?? json['pack'] as String? ?? ''),
      brand: brand,
      batchNumber: json['batchNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'medicine': medicineId,
        'name': name,
        'quantity': quantity,
        'pricePaise': pricePaise,
        'mrpPaise': mrpPaise,
        'isPrescriptionRequired': isPrescriptionRequired,
        'packSize': packSize,
        if (brand != null) 'brand': brand,
        if (batchNumber != null) 'batchNumber': batchNumber,
      };
}

/// Delivery address snapshot associated with the cart.
class CartDeliveryAddressSnapshot {
  final String? addressId;
  final String? pincode;
  final List<double>? coordinates; // [longitude, latitude]

  const CartDeliveryAddressSnapshot({
    this.addressId,
    this.pincode,
    this.coordinates,
  });

  factory CartDeliveryAddressSnapshot.fromJson(Map<String, dynamic> json) {
    List<double>? coords;
    if (json['location'] is Map && json['location']['coordinates'] is List) {
      final list = json['location']['coordinates'] as List;
      if (list.length >= 2) {
        coords = [
          (list[0] as num).toDouble(),
          (list[1] as num).toDouble(),
        ];
      }
    }
    return CartDeliveryAddressSnapshot(
      addressId: json['addressId'] as String?,
      pincode: json['pincode'] as String? ?? json['pinCode'] as String?,
      coordinates: coords,
    );
  }

  Map<String, dynamic> toJson() => {
        if (addressId != null) 'addressId': addressId,
        if (pincode != null) 'pincode': pincode,
        if (coordinates != null)
          'location': {
            'type': 'Point',
            'coordinates': coordinates,
          },
      };
}

/// Cart summary metadata returned by GET /cart.
class CartSummary {
  final int itemCount;
  final int uniqueMedicinesCount;
  final bool requiresPrescription;
  final bool hasPrescriptionAttached;

  const CartSummary({
    this.itemCount = 0,
    this.uniqueMedicinesCount = 0,
    this.requiresPrescription = false,
    this.hasPrescriptionAttached = false,
  });

  factory CartSummary.fromJson(Map<String, dynamic> json) {
    return CartSummary(
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      uniqueMedicinesCount: (json['uniqueMedicinesCount'] as num?)?.toInt() ?? 0,
      requiresPrescription: json['requiresPrescription'] == true,
      hasPrescriptionAttached: json['hasPrescriptionAttached'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'itemCount': itemCount,
        'uniqueMedicinesCount': uniqueMedicinesCount,
        'requiresPrescription': requiresPrescription,
        'hasPrescriptionAttached': hasPrescriptionAttached,
      };
}

/// Live catalog reconciliation warnings returned by GET /cart.
class CartWarning {
  final String type; // 'PRICE_CHANGED' or 'ITEM_UNAVAILABLE'
  final String? itemId;
  final String? name;
  final int? oldPricePaise;
  final int? newPricePaise;
  final String message;

  const CartWarning({
    required this.type,
    this.itemId,
    this.name,
    this.oldPricePaise,
    this.newPricePaise,
    required this.message,
  });

  bool get isPriceChange => type == 'PRICE_CHANGED';
  bool get isUnavailable => type == 'ITEM_UNAVAILABLE';

  factory CartWarning.fromJson(Map<String, dynamic> json) {
    return CartWarning(
      type: json['type'] as String? ?? 'PRICE_CHANGED',
      itemId: json['itemId'] as String?,
      name: json['name'] as String?,
      oldPricePaise: (json['oldPricePaise'] as num?)?.toInt(),
      newPricePaise: (json['newPricePaise'] as num?)?.toInt(),
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (itemId != null) 'itemId': itemId,
        if (name != null) 'name': name,
        if (oldPricePaise != null) 'oldPricePaise': oldPricePaise,
        if (newPricePaise != null) 'newPricePaise': newPricePaise,
        'message': message,
      };
}

/// Comprehensive model for MDP Customer Shopping Cart.
class CartModel {
  final String id;
  final String cartCode;
  final String? customer;
  final String status; // 'ACTIVE', 'LOCKED', 'ORDER_PLACED', 'ABANDONED'
  final String? allocatedStore;
  final CartDeliveryAddressSnapshot? deliveryAddress;
  final List<CartLineItem> items;
  final int itemsTotalPaise;
  final int discountPaise;
  final int deliveryFeePaise;
  final int totalPayablePaise;
  final String? couponCode;
  final String? prescriptionId;
  final DateTime? lockedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CartModel({
    required this.id,
    required this.cartCode,
    this.customer,
    this.status = 'ACTIVE',
    this.allocatedStore,
    this.deliveryAddress,
    this.items = const [],
    this.itemsTotalPaise = 0,
    this.discountPaise = 0,
    this.deliveryFeePaise = 0,
    this.totalPayablePaise = 0,
    this.couponCode,
    this.prescriptionId,
    this.lockedAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  static const CartModel empty = CartModel(
    id: '',
    cartCode: '',
    status: 'ACTIVE',
    items: [],
  );

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get isLocked => status.toUpperCase() == 'LOCKED';
  bool get isStoreAllocated => allocatedStore != null && allocatedStore!.isNotEmpty;
  bool get hasCoupon => couponCode != null && couponCode!.isNotEmpty;
  bool get hasPrescription => prescriptionId != null && prescriptionId!.isNotEmpty;

  int get totalCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get uniqueItemCount => items.length;

  double get itemsTotalInRupees => itemsTotalPaise / 100.0;
  double get discountInRupees => discountPaise / 100.0;
  double get deliveryFeeInRupees => deliveryFeePaise / 100.0;
  double get totalPayableInRupees => totalPayablePaise / 100.0;

  String get formattedItemsTotal {
    final val = itemsTotalPaise / 100.0;
    return '₹${itemsTotalPaise % 100 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(2)}';
  }

  String get formattedDiscount {
    final val = discountPaise / 100.0;
    return '₹${discountPaise % 100 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(2)}';
  }

  String get formattedDeliveryFee {
    if (deliveryFeePaise == 0) return 'FREE';
    final val = deliveryFeePaise / 100.0;
    return '₹${deliveryFeePaise % 100 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(2)}';
  }

  String get formattedTotalPayable {
    final val = totalPayablePaise / 100.0;
    return '₹${totalPayablePaise % 100 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(2)}';
  }

  /// Calculates seconds remaining on 15-minute checkout stock hold.
  int get remainingHoldSeconds {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now().toUtc()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isHoldExpired => isLocked && remainingHoldSeconds <= 0;

  CartModel copyWith({
    String? id,
    String? cartCode,
    String? customer,
    String? status,
    String? allocatedStore,
    CartDeliveryAddressSnapshot? deliveryAddress,
    List<CartLineItem>? items,
    int? itemsTotalPaise,
    int? discountPaise,
    int? deliveryFeePaise,
    int? totalPayablePaise,
    String? couponCode,
    String? prescriptionId,
    DateTime? lockedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartModel(
      id: id ?? this.id,
      cartCode: cartCode ?? this.cartCode,
      customer: customer ?? this.customer,
      status: status ?? this.status,
      allocatedStore: allocatedStore ?? this.allocatedStore,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      itemsTotalPaise: itemsTotalPaise ?? this.itemsTotalPaise,
      discountPaise: discountPaise ?? this.discountPaise,
      deliveryFeePaise: deliveryFeePaise ?? this.deliveryFeePaise,
      totalPayablePaise: totalPayablePaise ?? this.totalPayablePaise,
      couponCode: couponCode ?? this.couponCode,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      lockedAt: lockedAt ?? this.lockedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CartModel.fromJson(Map<String, dynamic> json) {
    // If wrapped in {"cart": {...}} extract cart inner map
    final map = (json['cart'] is Map<String, dynamic>)
        ? json['cart'] as Map<String, dynamic>
        : json;

    final rawId = map['_id'] as String? ?? map['id'] as String? ?? '';
    final code = map['cartCode'] as String? ?? '';
    final cust = map['customer'] as String?;
    final st = (map['status'] as String? ?? 'ACTIVE').toUpperCase();
    final store = map['allocatedStore'] as String?;

    CartDeliveryAddressSnapshot? addr;
    if (map['deliveryAddress'] is Map<String, dynamic>) {
      addr = CartDeliveryAddressSnapshot.fromJson(map['deliveryAddress'] as Map<String, dynamic>);
    }

    final rawItems = map['items'];
    final items = <CartLineItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(CartLineItem.fromJson(it));
        }
      }
    }

    final itemsTotal = (map['itemsTotalPaise'] as num?)?.toInt() ?? 0;
    final discount = (map['discountPaise'] as num?)?.toInt() ?? 0;
    final deliveryFee = (map['deliveryFeePaise'] as num?)?.toInt() ??
        (items.isEmpty || itemsTotal >= 50000 ? 0 : 4000);
    final totalPayable = (map['totalPayablePaise'] as num?)?.toInt() ??
        (itemsTotal - discount + deliveryFee).clamp(0, 999999999);

    final coupon = map['couponCode'] as String?;

    String? rxId;
    final rawRx = map['prescription'];
    if (rawRx is String) {
      rxId = rawRx;
    } else if (rawRx is Map) {
      rxId = rawRx['prescriptionId'] as String? ?? rawRx['_id'] as String?;
    }

    DateTime? parseDate(dynamic d) {
      if (d is String && d.isNotEmpty) {
        return DateTime.tryParse(d);
      }
      return null;
    }

    return CartModel(
      id: rawId,
      cartCode: code,
      customer: cust,
      status: st,
      allocatedStore: store,
      deliveryAddress: addr,
      items: items,
      itemsTotalPaise: itemsTotal,
      discountPaise: discount,
      deliveryFeePaise: deliveryFee,
      totalPayablePaise: totalPayable,
      couponCode: coupon,
      prescriptionId: rxId,
      lockedAt: parseDate(map['lockedAt']),
      expiresAt: parseDate(map['expiresAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'cartCode': cartCode,
        if (customer != null) 'customer': customer,
        'status': status,
        'allocatedStore': allocatedStore,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress!.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'itemsTotalPaise': itemsTotalPaise,
        'discountPaise': discountPaise,
        'deliveryFeePaise': deliveryFeePaise,
        'totalPayablePaise': totalPayablePaise,
        'couponCode': couponCode,
        'prescription': prescriptionId,
        if (lockedAt != null) 'lockedAt': lockedAt!.toUtc().toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };
}

/// Result of GET /cart with reconciliation metadata.
class GetCartResponse {
  final CartModel cart;
  final CartSummary summary;
  final List<CartWarning> warnings;

  const GetCartResponse({
    required this.cart,
    this.summary = const CartSummary(),
    this.warnings = const [],
  });

  factory GetCartResponse.fromJson(Map<String, dynamic> json) {
    final cartData = (json['cart'] is Map<String, dynamic>)
        ? json['cart'] as Map<String, dynamic>
        : json;
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};
    final warningsList = <CartWarning>[];

    if (json['warnings'] is List) {
      for (final w in json['warnings'] as List) {
        if (w is Map<String, dynamic>) {
          warningsList.add(CartWarning.fromJson(w));
        }
      }
    }

    return GetCartResponse(
      cart: CartModel.fromJson(cartData),
      summary: CartSummary.fromJson(summaryData),
      warnings: warningsList,
    );
  }
}

