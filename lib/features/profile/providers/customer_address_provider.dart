import 'package:flutter/foundation.dart';
import '../../../core/utils/pincode_validator.dart';
import '../models/customer_address.dart';
import '../repositories/address_repository.dart';

/// Provider managing customer delivery addresses and PIN code serviceability validation.
class CustomerAddressProvider extends ChangeNotifier {
  final AddressRepository repository;

  String? _userId;
  List<CustomerAddress> _addresses = const [];
  CustomerAddress? _selectedAddress;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  bool _disposed = false;
  Future<void>? _inFlightRefresh;
  DateTime? _lastFetchedAt;
  static const Duration _staleDuration = Duration(minutes: 5);

  CustomerAddressProvider(this.repository) {
    final initial = repository.cachedAddresses;
    if (initial.isNotEmpty) {
      _addresses = initial;
      _selectedAddress = _resolveDefault(initial);
    }
  }

  List<CustomerAddress> get addresses => _addresses;
  CustomerAddress? get selectedAddress => _selectedAddress;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  CustomerAddress? get defaultAddress => _resolveDefault(_addresses);

  bool get isSelectedAddressServiceable {
    final addr = _selectedAddress ?? defaultAddress;
    if (addr == null) return false;
    return addr.isServiceable;
  }

  List<CustomerAddress> filterByType(AddressType? type) {
    if (type == null) return _addresses;
    return _addresses.where((a) => a.addressType == type).toList();
  }

  CustomerAddress? _resolveDefault(List<CustomerAddress> list) {
    if (list.isEmpty) return null;
    final def = list.where((a) => a.isDefault).firstOrNull;
    return def ?? list.first;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _lastFetchedAt = null;
    if (userId == null || userId.isEmpty) {
      _addresses = const [];
      _selectedAddress = null;
      _error = null;
      _loading = false;
      _safeNotify();
      return;
    }
    // Hydrate from in-memory repository cache only; defer network sync until needed.
    final cached = repository.cachedAddresses;
    if (cached.isNotEmpty) {
      _addresses = cached;
      _selectedAddress ??= _resolveDefault(cached);
      _safeNotify();
    }
  }

  /// Ensures addresses are loaded from the server if missing or stale.
  Future<void> ensureLoaded() => refresh(force: false);

  Future<void> refresh({bool force = true}) {
    if (!force &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) < _staleDuration &&
        _addresses.isNotEmpty) {
      return Future.value();
    }
    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }

    final future = _doRefresh();
    _inFlightRefresh = future;
    future.whenComplete(() {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    });
    return future;
  }

  Future<void> _doRefresh() async {
    if (_addresses.isEmpty) {
      _loading = true;
      _safeNotify();
    }
    _error = null;
    try {
      final fresh = await repository.getAddresses();
      _addresses = fresh;
      _lastFetchedAt = DateTime.now();
      if (_selectedAddress == null || !_addresses.any((a) => a.id == _selectedAddress!.id)) {
        _selectedAddress = _resolveDefault(_addresses);
      } else {
        final current = _addresses.firstWhere((a) => a.id == _selectedAddress!.id);
        _selectedAddress = current;
      }
    } catch (_) {
      _error = 'Unable to sync addresses with the server.';
      _addresses = repository.cachedAddresses;
    }
    _loading = false;
    _safeNotify();
  }

  void selectAddress(CustomerAddress address) {
    _selectedAddress = address;
    _safeNotify();
  }

  Future<CustomerAddress?> addAddress(CustomerAddress address) async {
    _saving = true;
    _error = null;
    _safeNotify();

    try {
      final saved = await repository.addAddress(address);
      _addresses = repository.cachedAddresses;
      if (saved.isDefault || _selectedAddress == null) {
        _selectedAddress = saved;
      }
      _saving = false;
      _safeNotify();
      return saved;
    } catch (e) {
      _error = 'Failed to save address. Please try again.';
      _saving = false;
      _safeNotify();
      return null;
    }
  }

  Future<bool> updateAddress(CustomerAddress address) async {
    _saving = true;
    _error = null;
    _safeNotify();

    try {
      final updated = await repository.updateAddress(address);
      _addresses = repository.cachedAddresses;
      if (_selectedAddress?.id == updated.id) {
        _selectedAddress = updated;
      }
      _saving = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to update address. Please try again.';
      _saving = false;
      _safeNotify();
      return false;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    _error = null;
    try {
      await repository.deleteAddress(addressId);
      _addresses = repository.cachedAddresses;
      if (_selectedAddress?.id == addressId) {
        _selectedAddress = _resolveDefault(_addresses);
      }
      _safeNotify();
    } catch (_) {
      _error = 'Failed to delete address.';
      _safeNotify();
    }
  }

  Future<void> setDefault(String addressId) async {
    try {
      await repository.setDefaultAddress(addressId);
      _addresses = repository.cachedAddresses;
      _selectedAddress = _addresses.firstWhere(
        (a) => a.id == addressId,
        orElse: () => _addresses.first,
      );
      _safeNotify();
    } catch (_) {
      _error = 'Failed to set default address.';
      _safeNotify();
    }
  }

  /// Validates whether the address (or currently selected address) is eligible for order placement.
  /// Returns null if order placement is allowed, or a user-facing error message if blocked.
  String? validateForOrderPlacement([CustomerAddress? target]) {
    final address = target ?? _selectedAddress ?? defaultAddress;
    if (address == null) {
      return 'Please add or select a delivery address to place your order.';
    }

    if (!PincodeValidator.isValidFormat(address.pinCode)) {
      return 'Selected delivery address has an invalid PIN code (${address.pinCode}). Please update with a valid 6-digit PIN code.';
    }

    if (!address.isServiceable) {
      return 'Delivery is currently not available for PIN code ${address.pinCode}. Please select or add an address in a serviceable area to place your order.';
    }

    return null;
  }
}

