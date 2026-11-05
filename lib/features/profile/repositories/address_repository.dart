import 'package:uuid/uuid.dart';
import '../../../core/services/api_service.dart';
import '../models/customer_address.dart';

abstract interface class AddressRepository {
  List<CustomerAddress> get cachedAddresses;
  Future<List<CustomerAddress>> getAddresses();
  Future<CustomerAddress> addAddress(CustomerAddress address);
  Future<CustomerAddress> updateAddress(CustomerAddress address);
  Future<void> deleteAddress(String addressId);
  Future<void> setDefaultAddress(String addressId);
}

class ApiServiceAddressRepository implements AddressRepository {
  final List<CustomerAddress> _cachedAddresses = [];
  final Uuid _uuid = const Uuid();

  @override
  List<CustomerAddress> get cachedAddresses => List.unmodifiable(_cachedAddresses);

  ApiServiceAddressRepository([List<CustomerAddress>? initial]) {
    if (initial != null && initial.isNotEmpty) {
      _cachedAddresses.addAll(initial);
    } else {
      _initFromCacheOrDefault();
    }
  }

  void _initFromCacheOrDefault() {
    final cached = ApiService.cachedCustomerProfile;
    if (cached != null) {
      final cust = (cached['customer'] is Map ? cached['customer'] : cached) as Map<String, dynamic>;
      final addresses = cust['addresses'];
      if (addresses is List && addresses.isNotEmpty) {
        _parseAndAppend(addresses);
        return;
      }
    }

    // Default starter addresses (HOME, WORK, OTHER) conforming to 5. Customer Address Management
    _cachedAddresses.addAll([
      const CustomerAddress(
        id: 'addr_home_default',
        addressType: AddressType.home,
        addressLine1: 'Flat 402, Lotus Heights',
        addressLine2: 'Road No. 12, Banjara Hills',
        landmark: 'Near Care Hospital',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500034',
        contactName: 'Achyut Joshi',
        contactMobile: '9876543210',
        isDefault: true,
        latitude: 17.4156,
        longitude: 78.4357,
        eta: '22 Mins Express',
      ),
      const CustomerAddress(
        id: 'addr_work_default',
        addressType: AddressType.work,
        addressLine1: 'Building 9, Mindspace IT Park',
        addressLine2: 'HITEC City, Madhapur',
        landmark: 'Opposite Inorbit Mall',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500081',
        contactName: 'Achyut Joshi',
        contactMobile: '9876543210',
        isDefault: false,
        latitude: 17.4385,
        longitude: 78.3800,
        eta: '28 Mins Express',
      ),
      const CustomerAddress(
        id: 'addr_other_default',
        addressType: AddressType.other,
        addressLine1: 'House 18, Road No. 45',
        addressLine2: 'Jubilee Hills',
        landmark: 'Next to Apollo Clinic',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500033',
        contactName: 'Dr. Ramesh Joshi',
        contactMobile: '9848012345',
        isDefault: false,
        latitude: 17.4319,
        longitude: 78.4073,
        eta: '25 Mins Express',
      ),
    ]);
  }

  void _parseAndAppend(List<dynamic> remoteList) {
    for (final item in remoteList) {
      if (item is Map<String, dynamic>) {
        final address = CustomerAddress.fromJson(item);
        final existingIdx = _cachedAddresses.indexWhere(
          (a) => (a.id.isNotEmpty && a.id == address.id) ||
                 (a.addressLine1 == address.addressLine1 && a.pinCode == address.pinCode),
        );
        if (existingIdx >= 0) {
          _cachedAddresses[existingIdx] = address;
        } else {
          _cachedAddresses.add(address);
        }
      }
    }
  }

  @override
  Future<List<CustomerAddress>> getAddresses() async => cachedAddresses;

  @override
  Future<CustomerAddress> addAddress(CustomerAddress address) async {
    var toAdd = address;
    if (toAdd.id.isEmpty) {
      toAdd = toAdd.copyWith(id: 'addr_${_uuid.v4().substring(0, 8)}');
    }

    if (toAdd.isDefault) {
      // Clear previous default
      for (int i = 0; i < _cachedAddresses.length; i++) {
        if (_cachedAddresses[i].isDefault) {
          _cachedAddresses[i] = _cachedAddresses[i].copyWith(isDefault: false);
        }
      }
    } else if (_cachedAddresses.isEmpty) {
      toAdd = toAdd.copyWith(isDefault: true);
    }

    _cachedAddresses.add(toAdd);

    // Sync with backend if logged in
    try {
      if (ApiService.token != null) {
        final res = await ApiService.addAddress(
          ApiService.currentCustomerId,
          label: toAdd.typeKey,
          addressLine1: toAdd.addressLine1,
          addressLine2: toAdd.addressLine2.isNotEmpty ? toAdd.addressLine2 : null,
          landmark: toAdd.landmark.isNotEmpty ? toAdd.landmark : null,
          city: toAdd.city,
          state: toAdd.state,
          pincode: toAdd.pinCode,
          contactName: toAdd.contactName,
          contactMobile: toAdd.contactMobile,
          longitude: toAdd.longitude,
          latitude: toAdd.latitude,
          isDefault: toAdd.isDefault,
        );

        if (res is Map) {
          final serverId = res['_id'] as String? ?? res['id'] as String?;
          if (serverId != null && serverId.isNotEmpty) {
            final idx = _cachedAddresses.indexOf(toAdd);
            toAdd = toAdd.copyWith(id: serverId);
            if (idx >= 0) {
              _cachedAddresses[idx] = toAdd;
            }
          }
        }
      }
    } catch (_) {
      // Logged or handled without breaking local UX
    }

    return toAdd;
  }

  @override
  Future<CustomerAddress> updateAddress(CustomerAddress address) async {
    final idx = _cachedAddresses.indexWhere((a) => a.id == address.id);
    if (idx >= 0) {
      if (address.isDefault) {
        for (int i = 0; i < _cachedAddresses.length; i++) {
          if (i != idx && _cachedAddresses[i].isDefault) {
            _cachedAddresses[i] = _cachedAddresses[i].copyWith(isDefault: false);
          }
        }
      }
      _cachedAddresses[idx] = address;
    }

    // Sync with backend
    try {
      if (ApiService.token != null && address.id.isNotEmpty && !address.id.startsWith('addr_')) {
        await ApiService.updateAddress(
          ApiService.currentCustomerId,
          address.id,
          label: address.typeKey,
          addressLine1: address.addressLine1,
          addressLine2: address.addressLine2,
          landmark: address.landmark,
          city: address.city,
          state: address.state,
          pincode: address.pinCode,
          contactName: address.contactName,
          contactMobile: address.contactMobile,
          latitude: address.latitude,
          longitude: address.longitude,
          isDefault: address.isDefault,
        );
      }
    } catch (_) {}

    return address;
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    final wasDefault = _cachedAddresses.any((a) => a.id == addressId && a.isDefault);
    _cachedAddresses.removeWhere((a) => a.id == addressId);

    if (wasDefault && _cachedAddresses.isNotEmpty) {
      _cachedAddresses[0] = _cachedAddresses[0].copyWith(isDefault: true);
    }

    try {
      if (ApiService.token != null && addressId.isNotEmpty && !addressId.startsWith('addr_')) {
        await ApiService.deleteAddress(ApiService.currentCustomerId, addressId);
      }
    } catch (_) {}
  }

  @override
  Future<void> setDefaultAddress(String addressId) async {
    CustomerAddress? target;
    for (int i = 0; i < _cachedAddresses.length; i++) {
      final isMatch = _cachedAddresses[i].id == addressId;
      _cachedAddresses[i] = _cachedAddresses[i].copyWith(isDefault: isMatch);
      if (isMatch) target = _cachedAddresses[i];
    }

    if (target != null) {
      try {
        if (ApiService.token != null && addressId.isNotEmpty && !addressId.startsWith('addr_')) {
          await ApiService.updateAddress(
            ApiService.currentCustomerId,
            addressId,
            isDefault: true,
          );
        }
      } catch (_) {}
    }
  }
}

