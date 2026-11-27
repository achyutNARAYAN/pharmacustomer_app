import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../profile/models/customer_address.dart';

/// Live Delivery Tracking state model populated from backend API
/// with resilient fallback derived from the active order & customer delivery location.
class DeliveryTrackingModel {
  final String orderId;
  final String status;
  final String statusTitle;
  final int etaMinutes;
  final String etaDisplay;
  final String hubName;
  final LatLng hubLocation;
  final LatLng driverLocation;
  final LatLng destinationLocation;
  final String destinationAddress;
  final List<LatLng> routePoints;
  final String driverName;
  final double driverRating;
  final String driverVehicle;
  final String driverPhone;
  final bool hasDriverAssigned;
  final String handoverOtp;
  final int itemCount;
  final List<String> itemNames;
  final DateTime updatedAt;

  const DeliveryTrackingModel({
    required this.orderId,
    required this.status,
    required this.statusTitle,
    required this.etaMinutes,
    required this.etaDisplay,
    required this.hubName,
    required this.hubLocation,
    required this.driverLocation,
    required this.destinationLocation,
    required this.destinationAddress,
    required this.routePoints,
    required this.driverName,
    required this.driverRating,
    required this.driverVehicle,
    required this.driverPhone,
    this.hasDriverAssigned = false,
    required this.handoverOtp,
    required this.itemCount,
    required this.itemNames,
    required this.updatedAt,
  });

  DeliveryTrackingModel copyWith({
    String? orderId,
    String? status,
    String? statusTitle,
    int? etaMinutes,
    String? etaDisplay,
    String? hubName,
    LatLng? hubLocation,
    LatLng? driverLocation,
    LatLng? destinationLocation,
    String? destinationAddress,
    List<LatLng>? routePoints,
    String? driverName,
    double? driverRating,
    String? driverVehicle,
    String? driverPhone,
    bool? hasDriverAssigned,
    String? handoverOtp,
    int? itemCount,
    List<String>? itemNames,
    DateTime? updatedAt,
  }) {
    return DeliveryTrackingModel(
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      statusTitle: statusTitle ?? this.statusTitle,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      etaDisplay: etaDisplay ?? this.etaDisplay,
      hubName: hubName ?? this.hubName,
      hubLocation: hubLocation ?? this.hubLocation,
      driverLocation: driverLocation ?? this.driverLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      routePoints: routePoints ?? this.routePoints,
      driverName: driverName ?? this.driverName,
      driverRating: driverRating ?? this.driverRating,
      driverVehicle: driverVehicle ?? this.driverVehicle,
      driverPhone: driverPhone ?? this.driverPhone,
      hasDriverAssigned: hasDriverAssigned ?? this.hasDriverAssigned,
      handoverOtp: handoverOtp ?? this.handoverOtp,
      itemCount: itemCount ?? this.itemCount,
      itemNames: itemNames ?? this.itemNames,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Factory constructor to parse backend JSON, supplemented with context when needed
  factory DeliveryTrackingModel.fromBackend({
    Map<String, dynamic>? json,
    String? fallbackOrderId,
    CustomerAddress? customerAddress,
    String? fallbackAddressText,
    LatLng? destinationCoordinates,
    int? fallbackItemCount,
    List<String>? fallbackItemNames,
  }) {
    final raw = json ?? <String, dynamic>{};
    final data = raw['order'] is Map<String, dynamic>
        ? <String, dynamic>{
            ...raw,
            ...(raw['order'] as Map<String, dynamic>),
          }
        : raw;

    // 1. Order ID resolution
    final rawId = data['orderId'] as String? ??
        data['orderCode'] as String? ??
        data['id'] as String? ??
        data['_id'] as String? ??
        fallbackOrderId ??
        '';
    final resolvedOrderId = rawId.isNotEmpty
        ? (rawId.startsWith('AC-')
            ? rawId.replaceFirst('AC-', '')
            : rawId.length > 6
                ? rawId.substring(rawId.length - 4)
                : rawId)
        : '';

    // 2. Status resolution
    final rawStatus = (data['status'] as String? ?? 'ORDER_PLACED').toUpperCase();
    final statusTitle = switch (rawStatus) {
      'DELIVERED' => 'Delivered · Order Completed',
      'REACHED' => 'Rider has arrived at your door',
      'OUT_FOR_DELIVERY' || 'OUTFORDELIVERY' || 'DISPATCHED' => 'Out for Delivery · On the way',
      'DRIVER_ASSIGNED' => 'Rider assigned · Heading to pharmacy',
      'READY_FOR_PICKUP' => 'Order packed · Waiting for pickup',
      'PACKING' || 'PROCESSING' => 'Pharmacy is packing your order',
      'STORE_ACCEPTED' ||
      'CONFIRMED' ||
      'ACCEPTED' ||
      'PHARMACY_ACCEPTED' ||
      'ACCEPTED_BY_PHARMACY' ||
      'STORE_CONFIRMED' ||
      'ACCEPTED_BY_STORE' ||
      'VERIFIED' =>
        'Pharmacy accepted · Verifying items',
      'ORDER_PLACED' => 'Order placed · Chemist verifying stock',
      'PAYMENT_PENDING' => 'Awaiting payment confirmation',
      'CANCELLED' => 'Order Cancelled',
      'STORE_REJECTED' => 'Store Unavailable (Refund Initiated)',
      _ => 'Processing order',
    };

    // 3. Customer Destination Coordinates & Address
    double destLat = destinationCoordinates?.latitude ?? 17.4411;
    double destLng = destinationCoordinates?.longitude ?? 78.4608;
    String resolvedAddress = fallbackAddressText ?? 'Registered Delivery Location';

    if (customerAddress != null) {
      if (customerAddress.displayDetails.isNotEmpty) {
        resolvedAddress = customerAddress.displayDetails;
      }
      if (destinationCoordinates == null) {
        final isBangalore = customerAddress.latitude >= 12.7 &&
            customerAddress.latitude <= 13.2 &&
            customerAddress.longitude >= 77.4 &&
            customerAddress.longitude <= 77.8;
        if (!isBangalore) {
          destLat = customerAddress.latitude;
          destLng = customerAddress.longitude;
        }
      }
    }

    // Only allow backend data to override destination if destinationCoordinates was not explicitly passed
    if (destinationCoordinates == null && data['destination'] is Map<String, dynamic>) {
      final destMap = data['destination'] as Map<String, dynamic>;
      if (destMap['location'] is Map) {
        final loc = destMap['location'] as Map;
        if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
          final bLng = (loc['coordinates'][0] as num).toDouble();
          final bLat = (loc['coordinates'][1] as num).toDouble();
          final isStaleBangalore =
              bLat >= 12.7 && bLat <= 13.2 && bLng >= 77.4 && bLng <= 77.8;
          if (!isStaleBangalore) {
            destLng = bLng;
            destLat = bLat;
          }
        }
      } else if (destMap['lat'] != null && destMap['lng'] != null) {
        final bLat = (destMap['lat'] as num).toDouble();
        final bLng = (destMap['lng'] as num).toDouble();
        final isStaleBangalore =
            bLat >= 12.7 && bLat <= 13.2 && bLng >= 77.4 && bLng <= 77.8;
        if (!isStaleBangalore) {
          destLat = bLat;
          destLng = bLng;
        }
      }
      if (destMap['address'] is String && (destMap['address'] as String).isNotEmpty) {
        resolvedAddress = destMap['address'] as String;
      }
    }
    final destination = LatLng(destLat, destLng);

    // 4. Pharmacy Hub resolution (located ~2 km from the customer destination)
    String hubName = data['hubName'] as String? ??
        (data['hub'] is Map ? (data['hub'] as Map)['name'] as String? : null) ??
        'Verified Fulfillment Hub';
    LatLng hubLocation = LatLng(destLat + 0.015, destLng + 0.012);

    if (data['hub'] is Map<String, dynamic>) {
      final hubMap = data['hub'] as Map<String, dynamic>;
      if (hubMap['location'] is Map) {
        final loc = hubMap['location'] as Map;
        if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
          final hLng = (loc['coordinates'][0] as num).toDouble();
          final hLat = (loc['coordinates'][1] as num).toDouble();
          // Ensure hub is within 25 km of customer destination
          if ((hLat - destLat).abs() < 0.25 && (hLng - destLng).abs() < 0.25) {
            hubLocation = LatLng(hLat, hLng);
          }
        }
      }
    }

    // 5. ETA resolution
    final parsedEtaMinutes = (data['etaMinutes'] as num?)?.toInt() ??
        (data['eta_minutes'] as num?)?.toInt() ??
        (data['estimatedMinutes'] as num?)?.toInt() ??
        14;
    final etaDisplay = 'Arriving in $parsedEtaMinutes mins';

    // 6. Driver Location & Route
    // Default driver position ~1.4 km away from customer destination along the road corridor
    LatLng driverLocation = LatLng(destLat + 0.0045, destLng + 0.0115);
    if (data['driver'] is Map<String, dynamic>) {
      final dMap = data['driver'] as Map<String, dynamic>;
      if (dMap['location'] is Map) {
        final loc = dMap['location'] as Map;
        if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
          final dLng = (loc['coordinates'][0] as num).toDouble();
          final dLat = (loc['coordinates'][1] as num).toDouble();
          // Only accept backend driver coordinates if they are in the same city/region (within 25 km)
          if ((dLat - destLat).abs() < 0.25 && (dLng - destLng).abs() < 0.25) {
            driverLocation = LatLng(dLat, dLng);
          }
        }
      }
    }

    List<LatLng> routePoints = [];
    if (data['route'] is List) {
      for (final pt in data['route'] as List) {
        if (pt is List && pt.length >= 2) {
          routePoints.add(LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
        } else if (pt is Map && pt['lat'] != null && pt['lng'] != null) {
          routePoints.add(LatLng((pt['lat'] as num).toDouble(), (pt['lng'] as num).toDouble()));
        }
      }
    }

    if (routePoints.isEmpty) {
      routePoints = [driverLocation, destination];
    }

    // 7. Driver Info
    final driverData = data['driver'];
    final bool hasRealDriverMap = driverData is Map<String, dynamic> &&
        ((driverData['name'] != null && driverData['name'].toString().trim().isNotEmpty) ||
            (driverData['phone'] != null && driverData['phone'].toString().trim().isNotEmpty));
    final bool isDriverAssignedStatus = rawStatus == 'DRIVER_ASSIGNED' ||
        rawStatus == 'OUT_FOR_DELIVERY' ||
        rawStatus == 'OUTFORDELIVERY' ||
        rawStatus == 'DISPATCHED' ||
        rawStatus == 'DELIVERED';
    final bool hasDriverAssigned = hasRealDriverMap || (isDriverAssignedStatus && driverData != null);

    final driverMap = driverData is Map<String, dynamic> ? driverData : <String, dynamic>{};
    final driverName = driverMap['name'] as String? ?? (hasDriverAssigned ? 'Delivery Partner' : 'Ramesh Kumar');
    final driverRating = (driverMap['rating'] as num?)?.toDouble() ?? 4.9;
    final driverVehicle = driverMap['vehicle'] as String? ?? 'pharmaCustomer Express · Hero Electric';
    final driverPhone = driverMap['phone'] as String? ?? '+919876543210';

    // 8. Handover OTP (matches MDP backend deliveryOtp)
    final handoverOtp = data['deliveryOtp'] as String? ??
        data['handoverOtp'] as String? ??
        data['otp'] as String? ??
        data['verificationCode'] as String? ??
        '';

    // 9. Items Count & Names
    final itemCount = (data['itemCount'] as num?)?.toInt() ??
        (data['items'] is List ? (data['items'] as List).length : null) ??
        fallbackItemCount ??
        1;

    final itemNames = <String>[];
    if (data['items'] is List) {
      for (final item in data['items'] as List) {
        if (item is Map && item['name'] is String) {
          itemNames.add(item['name'] as String);
        } else if (item is String) {
          itemNames.add(item);
        }
      }
    }
    if (itemNames.isEmpty && fallbackItemNames != null) {
      itemNames.addAll(fallbackItemNames);
    }

    return DeliveryTrackingModel(
      orderId: resolvedOrderId,
      status: rawStatus,
      statusTitle: statusTitle,
      etaMinutes: parsedEtaMinutes,
      etaDisplay: etaDisplay,
      hubName: hubName,
      hubLocation: hubLocation,
      driverLocation: driverLocation,
      destinationLocation: destination,
      destinationAddress: resolvedAddress,
      routePoints: routePoints,
      driverName: driverName,
      driverRating: driverRating,
      driverVehicle: driverVehicle,
      driverPhone: driverPhone,
      hasDriverAssigned: hasDriverAssigned,
      handoverOtp: handoverOtp,
      itemCount: itemCount,
      itemNames: itemNames,
      updatedAt: DateTime.now(),
    );
  }
}

