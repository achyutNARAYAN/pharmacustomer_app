import 'package:flutter/material.dart';
import '../../../core/utils/pincode_validator.dart';

/// Supported types of customer delivery addresses.
enum AddressType {
  home('HOME', 'Home', Icons.home_rounded),
  work('WORK', 'Work', Icons.business_rounded),
  other('OTHER', 'Other', Icons.location_on_rounded);

  final String key;
  final String displayName;
  final IconData icon;

  const AddressType(this.key, this.displayName, this.icon);

  static AddressType fromString(String? value) {
    if (value == null) return AddressType.home;
    final normalized = value.trim().toUpperCase();
    return switch (normalized) {
      'HOME' || 'RESIDENCE' || 'HOUSE' => AddressType.home,
      'WORK' || 'OFFICE' => AddressType.work,
      _ => AddressType.other,
    };
  }
}

/// Domain model representing a customer's delivery address.
///
/// Contains all 10 mandatory fields specified by Customer Address Management:
/// • Address ID
/// • Address Line 1
/// • Address Line 2
/// • Landmark
/// • City
/// • State
/// • PIN Code
/// • Contact Name
/// • Contact Mobile
/// • Address Type (HOME, WORK, OTHER)
/// • Default Address flag
///
/// Includes PIN code serviceability validation to enforce pre-order checks.
@immutable
class CustomerAddress {
  final String id;
  final String addressLine1;
  final String addressLine2;
  final String landmark;
  final String city;
  final String state;
  final String pinCode;
  final String contactName;
  final String contactMobile;
  final AddressType addressType;
  final bool isDefault;
  final double latitude;
  final double longitude;
  final String eta;

  const CustomerAddress({
    required this.id,
    required this.addressLine1,
    this.addressLine2 = '',
    this.landmark = '',
    required this.city,
    required this.state,
    required this.pinCode,
    required this.contactName,
    required this.contactMobile,
    this.addressType = AddressType.home,
    this.isDefault = false,
    this.latitude = 12.9270,
    this.longitude = 77.6720,
    this.eta = '22 Mins Express',
  });

  /// Validates whether this address's PIN code is serviceable by the dark store/delivery network.
  bool get isServiceable => PincodeValidator.isServiceable(pinCode);

  /// String representation of the address type ('HOME', 'WORK', 'OTHER').
  String get typeKey => addressType.key;

  /// User-friendly title for UI display.
  String get typeDisplayName => addressType.displayName;

  /// Full multi-line address suitable for shipping labels and cards.
  String get formattedAddress {
    final parts = <String>[
      addressLine1,
      if (addressLine2.trim().isNotEmpty) addressLine2,
      if (landmark.trim().isNotEmpty) 'Near $landmark',
      '$city, $state - $pinCode',
    ];
    return parts.join('\n');
  }

  /// Compact single-line address summary.
  String get displayDetails {
    final list = [
      addressLine1,
      if (addressLine2.trim().isNotEmpty) addressLine2,
      if (landmark.trim().isNotEmpty) landmark,
      city,
      state,
      pinCode,
    ];
    final joined = list.where((s) => s.trim().isNotEmpty).join(', ');
    return joined.isNotEmpty ? joined : addressLine1;
  }

  /// Contact info label (e.g. "Achyut • 9876543210").
  String get contactDisplay {
    final parts = [contactName, contactMobile].where((s) => s.trim().isNotEmpty);
    return parts.join(' • ');
  }

  CustomerAddress copyWith({
    String? id,
    String? addressLine1,
    String? addressLine2,
    String? landmark,
    String? city,
    String? state,
    String? pinCode,
    String? contactName,
    String? contactMobile,
    AddressType? addressType,
    bool? isDefault,
    double? latitude,
    double? longitude,
    String? eta,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pinCode: pinCode ?? this.pinCode,
      contactName: contactName ?? this.contactName,
      contactMobile: contactMobile ?? this.contactMobile,
      addressType: addressType ?? this.addressType,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      eta: eta ?? this.eta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'label': addressType.key,
      'type': addressType.key,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pinCode': pinCode,
      'pincode': pinCode,
      'contactName': contactName,
      'contactMobile': contactMobile,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
      'location': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'eta': eta,
    };
  }

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] as String? ??
        json['id'] as String? ??
        json['addressId'] as String? ??
        '';

    final rawType = json['addressType'] as String? ??
        json['type'] as String? ??
        json['label'] as String? ??
        'HOME';

    final pin = json['pinCode'] as String? ??
        json['pincode'] as String? ??
        json['postalCode'] as String? ??
        '';

    double lat = 12.9270;
    double lng = 77.6720;
    if (json['location'] is Map && json['location']['coordinates'] is List) {
      final coords = json['location']['coordinates'] as List;
      if (coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    } else if (json['latitude'] != null && json['longitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
      lng = (json['longitude'] as num).toDouble();
    }

    return CustomerAddress(
      id: id,
      addressLine1: json['addressLine1'] as String? ?? '',
      addressLine2: json['addressLine2'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pinCode: pin,
      contactName: json['contactName'] as String? ?? 'Customer',
      contactMobile: json['contactMobile'] as String? ?? '9876543210',
      addressType: AddressType.fromString(rawType),
      isDefault: json['isDefault'] as bool? ?? false,
      latitude: lat,
      longitude: lng,
      eta: json['eta'] as String? ?? '22 Mins Express',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAddress &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          addressLine1 == other.addressLine1 &&
          addressLine2 == other.addressLine2 &&
          landmark == other.landmark &&
          city == other.city &&
          state == other.state &&
          pinCode == other.pinCode &&
          contactName == other.contactName &&
          contactMobile == other.contactMobile &&
          addressType == other.addressType &&
          isDefault == other.isDefault;

  @override
  int get hashCode =>
      id.hashCode ^
      addressLine1.hashCode ^
      addressLine2.hashCode ^
      landmark.hashCode ^
      city.hashCode ^
      state.hashCode ^
      pinCode.hashCode ^
      contactName.hashCode ^
      contactMobile.hashCode ^
      addressType.hashCode ^
      isDefault.hashCode;
}

