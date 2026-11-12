import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../../features/cart/models/cart_models.dart';
import '../../features/cart/models/cart_snapshot.dart';
import '../../features/cart/repositories/cart_repository.dart';
import '../services/api_service.dart';
import 'load_status.dart';

/// Senior Production-Grade CartNotifier managing local offline cache,
/// 11 REST API endpoints, FinTech integer paise calculations,
/// 4km store allocation, and 15-minute checkout stock hold countdown.
class CartNotifier extends ChangeNotifier implements PersistedProvider {
  static final RegExp _objectIdRegExp = RegExp(r'^[0-9a-fA-F]{24}$');

  // Runtime cache mapping medicine names/slugs to real MongoDB ObjectIds fetched from API
  static final Map<String, String> _nameToObjectIdCache = {};

  final CartRepository? _repository;

  // Local fallback items & prescriptions (offline/guest)
  final Map<String, CartItem> _localItems = {};
  final List<String> _localPrescriptionIds = [];

  // Authoritative remote cart state from MDP Cart & Checkout API
  CartModel? _remoteCart;
  CartSummary _summary = const CartSummary();
  List<CartWarning> _warnings = const [];

  String? _userId;
  LoadStatus _status = LoadStatus.uninitialized;
  bool _disposed = false;

  // Action states & feedback
  bool _isStoreAllocating = false;
  bool _isApplyingCoupon = false;
  bool _isCheckingOut = false;
  String? _actionError;
  String? _storeAllocationMessage;
  String? _allocatedStoreId;

  // 15-minute stock hold countdown timer
  Timer? _stockHoldTimer;
  int _remainingHoldSeconds = 0;

  CartNotifier([this._repository, CartSnapshot? initial]) {
    if (initial != null) {
      for (final item in initial.lines) {
        _localItems[item.id] = item;
      }
      _localPrescriptionIds.addAll(initial.prescriptionIds);
      _status = LoadStatus.ready;
    }
  }

  // ── Existing Public API (100% Backward Compatible) ──────────────────────────

  /// All line items in cart. If remote cart is synchronized, returns mapped items;
  /// otherwise returns local cached items.
  List<CartItem> get items {
    if (_remoteCart != null && _remoteCart!.items.isNotEmpty) {
      return _remoteCart!.items.map((i) => i.toCartItem()).toList();
    }
    return _localItems.values.toList();
  }

  /// Total units in cart across all items.
  int get totalCount {
    if (_remoteCart != null) {
      return _remoteCart!.totalCount;
    }
    return _localItems.values.fold(0, (sum, i) => sum + i.quantity);
  }

  /// Total price payable in Rupees (Double for legacy UI widgets).
  double get totalPrice {
    if (_remoteCart != null) {
      return _remoteCart!.totalPayableInRupees;
    }
    return _localItems.values.fold(0.0, (sum, i) => sum + i.total);
  }

  /// Returns quantity of an item by line item ID, medicine ID, or cached slug.
  int quantityOf(String id) {
    if (_remoteCart != null) {
      for (final item in _remoteCart!.items) {
        if (item.id == id || item.medicineId == id) {
          return item.quantity;
        }
      }
    }
    final mapped = _nameToObjectIdCache[id];
    if (mapped != null && _remoteCart != null) {
      for (final item in _remoteCart!.items) {
        if (item.id == mapped || item.medicineId == mapped) {
          return item.quantity;
        }
      }
    }
    return _localItems[id]?.quantity ?? 0;
  }

  LoadStatus get status => _status;

  String? get prescriptionId {
    if (_remoteCart?.prescriptionId != null && _remoteCart!.prescriptionId!.isNotEmpty) {
      return _remoteCart!.prescriptionId;
    }
    return _localPrescriptionIds.isNotEmpty ? _localPrescriptionIds.first : null;
  }

  List<String> get prescriptionIds {
    if (_remoteCart?.prescriptionId != null) {
      return [_remoteCart!.prescriptionId!];
    }
    return List.unmodifiable(_localPrescriptionIds);
  }

  bool get hasRxLines {
    if (_summary.requiresPrescription) return true;
    if (_remoteCart != null) {
      return _remoteCart!.items.any((i) => i.isPrescriptionRequired);
    }
    return _localItems.values.any((i) => i.requiresPrescription);
  }

  bool get hasPrescriptionAttached {
    if (_summary.hasPrescriptionAttached) return true;
    if (_remoteCart?.hasPrescription == true) return true;
    return _localPrescriptionIds.isNotEmpty;
  }

  int get lineCount => _remoteCart?.items.length ?? _localItems.length;

  // ── Production FinTech & Backend Specific Getters ─────────────────────────

  CartModel? get remoteCart => _remoteCart;
  CartSummary get summary => _summary;
  List<CartWarning> get warnings => _warnings;

  /// Whole integer paise fields (1 INR = 100 paise)
  int get itemsTotalPaise => _remoteCart?.itemsTotalPaise ?? (totalPrice * 100).round();
  int get discountPaise => _remoteCart?.discountPaise ?? 0;
  int get deliveryFeePaise => _remoteCart?.deliveryFeePaise ?? (items.isEmpty || itemsTotalPaise >= 50000 ? 0 : 4000);
  int get totalPayablePaise => _remoteCart?.totalPayablePaise ?? (itemsTotalPaise - discountPaise + deliveryFeePaise);

  String? get couponCode => _remoteCart?.couponCode;
  String? get allocatedStore => _allocatedStoreId ?? _remoteCart?.allocatedStore;
  String? get storeAllocationMessage => _storeAllocationMessage;

  bool get isStoreAllocating => _isStoreAllocating;
  bool get isApplyingCoupon => _isApplyingCoupon;
  bool get isCheckingOut => _isCheckingOut;
  String? get actionError => _actionError;

  bool get isLocked => _remoteCart?.isLocked ?? false;
  int get remainingHoldSeconds => _remainingHoldSeconds;

  String get remainingHoldFormatted {
    if (_remainingHoldSeconds <= 0) return '00:00';
    final minutes = _remainingHoldSeconds ~/ 60;
    final seconds = _remainingHoldSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ── Internal Helpers ──────────────────────────────────────────────────────

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _schedulePersist() {
    if (_repository != null) {
      final snapshot = CartSnapshot(
        lines: items,
        prescriptionIds: prescriptionIds,
      );
      _repository.schedulePersist(_userId, snapshot);
    }
  }

  void _startHoldTimer(DateTime expiresAt) {
    _stockHoldTimer?.cancel();
    final now = DateTime.now().toUtc();
    _remainingHoldSeconds = expiresAt.difference(now).inSeconds;
    if (_remainingHoldSeconds <= 0) {
      _remainingHoldSeconds = 0;
      _safeNotify();
      return;
    }

    _stockHoldTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final currentNow = DateTime.now().toUtc();
      final remaining = expiresAt.difference(currentNow).inSeconds;
      if (remaining <= 0) {
        _remainingHoldSeconds = 0;
        timer.cancel();
        _safeNotify();
        // Automatically refresh cart when hold expires
        refresh();
      } else {
        _remainingHoldSeconds = remaining;
        _safeNotify();
      }
    });
  }

  void _applyRemoteCart(CartModel cart, {CartSummary? summary, List<CartWarning>? warnings}) {
    _remoteCart = cart;
    if (summary != null) _summary = summary;
    if (warnings != null) _warnings = warnings;

    if (cart.allocatedStore != null && cart.allocatedStore!.isNotEmpty) {
      _allocatedStoreId = cart.allocatedStore;
    }

    // Mirror to local cache for offline persistence
    _localItems.clear();
    for (final item in cart.items) {
      _localItems[item.medicineId] = item.toCartItem();
    }
    _localPrescriptionIds.clear();
    if (cart.prescriptionId != null && cart.prescriptionId!.isNotEmpty) {
      _localPrescriptionIds.add(cart.prescriptionId!);
    }

    if (cart.isLocked && cart.expiresAt != null) {
      _startHoldTimer(cart.expiresAt!);
    } else {
      _stockHoldTimer?.cancel();
      _remainingHoldSeconds = 0;
    }

    _schedulePersist();
    _safeNotify();
  }

  // ── 11 Cart & Checkout REST API Integrations ──────────────────────────────

  /// 1. Sync active customer cart with live catalogue pricing and summary flags
  Future<void> syncRemoteCart() async {
    if (_repository == null || ApiService.token == null) return;
    try {
      final envelope = await _repository.fetchRemoteCartEnvelope();
      if (envelope != null) {
        _applyRemoteCart(
          envelope.cart,
          summary: envelope.summary,
          warnings: envelope.warnings,
        );
      }
    } catch (e) {
      _actionError = e.toString();
      _safeNotify();
    }
  }

  /// 2. Add item to cart via API (medicineId, quantity: 1..50)
  Future<void> addMedicine(String medicineId, {int quantity = 1, CartItem? localFallback}) async {
    _actionError = null;

    // Optimistic local update so UI reflects the addition immediately
    final itemKey = localFallback?.id ?? medicineId;
    if (localFallback != null) {
      _localItems[itemKey] = localFallback.copyWith(
        quantity: (_localItems[itemKey]?.quantity ?? 0) + quantity,
        updatedAt: DateTime.now().toUtc(),
      );
      _schedulePersist();
      _safeNotify();
    }

    String resolvedId = medicineId;

    // Resolve non-ObjectId identifiers (e.g. slugs or titles) to real 24-hex MongoDB ObjectIds
    if (!_objectIdRegExp.hasMatch(resolvedId)) {
      final cached = _nameToObjectIdCache[medicineId] ??
          _nameToObjectIdCache[localFallback?.name ?? ''];
      if (cached != null) {
        resolvedId = cached;
      } else {
        try {
          final query = (localFallback?.name ?? medicineId).replaceAll('_', ' ').split(' ').first;
          final matches = await ApiService.searchMedicines(search: query);
          if (matches.isNotEmpty) {
            for (final m in matches) {
              final candidate = m['_id'] as String? ?? m['id'] as String?;
              if (candidate != null && _objectIdRegExp.hasMatch(candidate)) {
                resolvedId = candidate;
                _nameToObjectIdCache[medicineId] = candidate;
                if (localFallback?.name != null) {
                  _nameToObjectIdCache[localFallback!.name] = candidate;
                }
                break;
              }
            }
          }
        } catch (_) {}
      }
    }

    // Only call the remote API if the medicineId is a valid 24-character hex MongoDB ObjectId
    if (_objectIdRegExp.hasMatch(resolvedId) && ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.addRemoteItem(resolvedId, quantity);
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
        }
      } catch (e) {
        final errorStr = e.toString();
        // If the backend returns NOT_FOUND (404), the ID was either mock/fake or deleted.
        // Try searching by medicine name to resolve the true live MongoDB ObjectId.
        if (errorStr.contains('not found') || errorStr.contains('NOT_FOUND') || errorStr.contains('404')) {
          final queryName = localFallback?.name ?? medicineId.replaceAll('_', ' ');
          if (queryName.isNotEmpty) {
            try {
              final query = queryName.split(' ').first;
              final matches = await ApiService.searchMedicines(search: query);
              for (final m in matches) {
                final candidate = m['_id'] as String? ?? m['id'] as String?;
                if (candidate != null && _objectIdRegExp.hasMatch(candidate) && candidate != resolvedId) {
                  final retryCart = await _repository.addRemoteItem(candidate, quantity);
                  if (retryCart != null) {
                    _nameToObjectIdCache[medicineId] = candidate;
                    _nameToObjectIdCache[queryName] = candidate;
                    _applyRemoteCart(retryCart);
                    return;
                  }
                }
              }
            } catch (_) {}
          }
          // If still not found on remote catalogue, preserve item safely in local cart
          debugPrint('[CartNotifier] Medicine "$resolvedId" not in remote database; preserved in local cart.');
          _actionError = null;
          _safeNotify();
          return;
        }

        _actionError = e.toString();
        _safeNotify();
        // Never rethrow unhandled exceptions in background fire-and-forget UI calls
      }
    }
  }

  /// 3. Update quantity of existing cart line item (lineItemId: _id, quantity: 1..50)
  Future<void> updateItemQuantity(String lineItemId, int newQuantity) async {
    _actionError = null;
    if (newQuantity < 1) {
      await removeCartItem(lineItemId);
      return;
    }

    if (_objectIdRegExp.hasMatch(lineItemId) && ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.updateRemoteQuantity(lineItemId, newQuantity);
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
          return;
        }
      } catch (e) {
        _actionError = e.toString();
        _safeNotify();
      }
    }

    // Local fallback update
    for (final entry in _localItems.entries) {
      if (entry.value.id == lineItemId || entry.key == lineItemId) {
        final updated = entry.value.copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now().toUtc(),
        );
        _localItems[entry.key] = updated;
        _schedulePersist();
        _safeNotify();
        break;
      }
    }
  }

  /// 4. Remove a line item from active cart by line item _id
  Future<void> removeCartItem(String lineItemId) async {
    _actionError = null;

    if (_objectIdRegExp.hasMatch(lineItemId) && ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.removeRemoteItem(lineItemId);
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
          return;
        }
      } catch (e) {
        _actionError = e.toString();
        _safeNotify();
      }
    }

    // Local fallback removal
    String? keyToRemove;
    for (final entry in _localItems.entries) {
      if (entry.value.id == lineItemId || entry.key == lineItemId) {
        keyToRemove = entry.key;
        break;
      }
    }
    if (keyToRemove != null) {
      _localItems.remove(keyToRemove);
      _schedulePersist();
      _safeNotify();
    }
  }

  /// 5. Clear entire cart
  Future<void> clearAll() async {
    _actionError = null;
    _allocatedStoreId = null;
    _storeAllocationMessage = null;
    _stockHoldTimer?.cancel();
    _remainingHoldSeconds = 0;

    if (ApiService.token != null && _repository != null) {
      try {
        final cleared = await _repository.clearRemoteCart();
        if (cleared != null) {
          _applyRemoteCart(cleared);
          return;
        }
      } catch (e) {
        _actionError = e.toString();
        _safeNotify();
      }
    }

    _localItems.clear();
    _localPrescriptionIds.clear();
    _remoteCart = null;
    _summary = const CartSummary();
    _warnings = const [];
    _schedulePersist();
    _safeNotify();
  }

  /// 6. Preview 4km blind store allocation with FEFO check
  Future<bool> allocateStore(String addressId) async {
    _isStoreAllocating = true;
    _actionError = null;
    _safeNotify();

    try {
      if (ApiService.token != null && _repository != null) {
        final res = await _repository.allocateStoreRemote(addressId);
        if (res != null) {
          _storeAllocationMessage = res['message'] as String? ?? 'Store allocated successfully within 4km';
          if (res['cart'] is Map<String, dynamic>) {
            final cart = CartModel.fromJson(res['cart'] as Map<String, dynamic>);
            _applyRemoteCart(cart);
            _allocatedStoreId = cart.allocatedStore;
          }
          _isStoreAllocating = false;
          _safeNotify();
          return true;
        }
      }
      _isStoreAllocating = false;
      _safeNotify();
      return true;
    } catch (e) {
      _isStoreAllocating = false;
      _actionError = e.toString();
      _storeAllocationMessage = null;
      _safeNotify();
      return false;
    }
  }

  /// 7. Attach verified (APPROVED) prescription to active cart
  Future<bool> attachPrescriptionId(String prescriptionId) async {
    _actionError = null;

    if (ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.attachPrescriptionRemote(prescriptionId);
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
          return true;
        }
      } catch (e) {
        _actionError = e.toString();
        _safeNotify();
        return false;
      }
    }

    // Local fallback
    if (!_localPrescriptionIds.contains(prescriptionId)) {
      _localPrescriptionIds.add(prescriptionId);
      _schedulePersist();
      _safeNotify();
    }
    return true;
  }

  /// 8. Remove attached prescription from active cart
  Future<bool> removePrescriptionId() async {
    _actionError = null;

    if (ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.removePrescriptionRemote();
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
          return true;
        }
      } catch (e) {
        _actionError = e.toString();
        _safeNotify();
        return false;
      }
    }

    _localPrescriptionIds.clear();
    _schedulePersist();
    _safeNotify();
    return true;
  }

  /// 9. Apply promotional coupon code (e.g. WELCOME50, SAVE10)
  Future<bool> applyCouponCode(String code) async {
    _isApplyingCoupon = true;
    _actionError = null;
    _safeNotify();

    try {
      if (ApiService.token != null && _repository != null) {
        final updatedCart = await _repository.applyCouponRemote(code);
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
          _isApplyingCoupon = false;
          _safeNotify();
          return true;
        }
      }
      _isApplyingCoupon = false;
      _safeNotify();
      return false;
    } catch (e) {
      _isApplyingCoupon = false;
      _actionError = e.toString();
      _safeNotify();
      return false;
    }
  }

  /// 10. Remove applied coupon code
  Future<bool> removeCouponCode() async {
    _actionError = null;

    try {
      if (ApiService.token != null && _repository != null) {
        final updatedCart = await _repository.removeCouponRemote();
        if (updatedCart != null) {
          _applyRemoteCart(updatedCart);
          return true;
        }
      }
      return true;
    } catch (e) {
      _actionError = e.toString();
      _safeNotify();
      return false;
    }
  }

  /// 11. Atomic checkout orchestration & 15-minute stock hold
  Future<CartModel?> performCheckout({
    required String addressId,
    String? prescriptionId,
    String? couponCode,
  }) async {
    _isCheckingOut = true;
    _actionError = null;
    _safeNotify();

    try {
      if (ApiService.token != null && _repository != null) {
        final lockedCart = await _repository.checkoutRemote(
          addressId: addressId,
          prescriptionId: prescriptionId,
          couponCode: couponCode,
        );
        if (lockedCart != null) {
          _applyRemoteCart(lockedCart);
          _isCheckingOut = false;
          _safeNotify();
          return lockedCart;
        }
      }
      _isCheckingOut = false;
      _safeNotify();
      return null;
    } catch (e) {
      _isCheckingOut = false;
      _actionError = e.toString();
      _safeNotify();
      rethrow;
    }
  }

  // ── Legacy Mutation Overrides ─────────────────────────────────────────────

  void add(CartItem item) {
    CartLineItem? existingRemoteItem;
    final mapped = _nameToObjectIdCache[item.id] ?? _nameToObjectIdCache[item.name];

    if (_remoteCart != null) {
      for (final r in _remoteCart!.items) {
        if (r.id == item.id ||
            r.medicineId == item.id ||
            (mapped != null && (r.id == mapped || r.medicineId == mapped))) {
          existingRemoteItem = r;
          break;
        }
      }
    }

    if (existingRemoteItem != null) {
      updateItemQuantity(existingRemoteItem.id, existingRemoteItem.quantity + 1);
    } else {
      addMedicine(item.id, quantity: 1, localFallback: item);
    }
  }

  void remove(String id) {
    CartLineItem? existingRemoteItem;
    final mapped = _nameToObjectIdCache[id];

    if (_remoteCart != null) {
      for (final r in _remoteCart!.items) {
        if (r.id == id ||
            r.medicineId == id ||
            (mapped != null && (r.id == mapped || r.medicineId == mapped))) {
          existingRemoteItem = r;
          break;
        }
      }
    }

    if (existingRemoteItem != null) {
      if (existingRemoteItem.quantity > 1) {
        updateItemQuantity(existingRemoteItem.id, existingRemoteItem.quantity - 1);
      } else {
        removeCartItem(existingRemoteItem.id);
      }
      return;
    }

    if (!_localItems.containsKey(id)) return;
    final current = _localItems[id]!;
    if (current.quantity > 1) {
      _localItems[id] = current.copyWith(
        quantity: current.quantity - 1,
        updatedAt: DateTime.now().toUtc(),
      );
    } else {
      _localItems.remove(id);
    }
    _schedulePersist();
    _safeNotify();
  }

  void clear() {
    clearAll();
  }

  void attachPrescription(String prescriptionId) {
    attachPrescriptionId(prescriptionId);
  }

  void detachPrescription(String prescriptionId) {
    removePrescriptionId();
  }

  // ── PersistedProvider Contract ────────────────────────────────────────────

  @override
  Future<void> init() async {
    if (_repository == null) {
      _status = LoadStatus.ready;
      _safeNotify();
      return;
    }

    _status = LoadStatus.hydrating;
    _safeNotify();

    final snapshot = await _repository.hydrate(_userId);
    _localItems.clear();
    for (final item in snapshot.lines) {
      _localItems[item.id] = item;
    }
    _localPrescriptionIds.clear();
    _localPrescriptionIds.addAll(snapshot.prescriptionIds);

    _status = LoadStatus.ready;
    _safeNotify();

    // Reconcile with remote server if user is logged in
    if (_userId != null && ApiService.token != null) {
      await syncRemoteCart();
    }
  }

  @override
  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;

    scheduleMicrotask(() async {
      if (_disposed) return;
      await init();
    });
  }

  @override
  Future<void> refresh() async {
    await syncRemoteCart();
  }

  @override
  void reset() {
    _stockHoldTimer?.cancel();
    _remainingHoldSeconds = 0;
    _localItems.clear();
    _localPrescriptionIds.clear();
    _remoteCart = null;
    _summary = const CartSummary();
    _warnings = const [];
    _status = LoadStatus.ready;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stockHoldTimer?.cancel();
    super.dispose();
  }
}
