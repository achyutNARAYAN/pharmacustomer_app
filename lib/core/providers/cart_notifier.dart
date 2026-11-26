import 'dart:async';
import 'package:flutter/foundation.dart';

import '../errors/failures.dart';
import '../models/cart_item.dart';
import '../../features/cart/models/cart_models.dart';
import '../../features/cart/models/cart_snapshot.dart';
import '../../features/cart/repositories/cart_repository.dart';
import '../services/api_service.dart';
import 'load_status.dart';

/// Senior Production-Grade CartNotifier managing local offline cache,
/// 11 REST API endpoints, FinTech integer paise calculations,
/// 4km store allocation, and 15-minute checkout stock hold countdown.
class CartNotifier extends ChangeNotifier {
  static final RegExp _objectIdRegExp = RegExp(r'^[0-9a-fA-F]{24}$');

  // Runtime cache mapping medicine names/slugs to real MongoDB ObjectIds fetched from API
  static final Map<String, String> _nameToObjectIdCache = {};

  final CartRepository? _repository;

  // Local fallback items & prescriptions (offline/guest)
  final Map<String, CartItem> _localItems = {};
  final List<String> _localPrescriptionIds = [];
  String? _attachedPrescriptionName;

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
  bool _userExplicitlyDetachedRx = false;

  // ── Debounced Synchronization State ──────────────────────────────────────
  static const Duration _debounceDuration = Duration(milliseconds: 400);
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, int> _pendingQuantities = {};
  final Map<String, CartItem> _pendingFallbackItems = {};
  final Set<String> _inFlightSyncs = {};

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
    if (_remoteCart != null) {
      return _remoteCart!.items;
    }
    final seen = <String>{};
    final unique = <CartItem>[];
    for (final item in _localItems.values) {
      if (seen.add(item.id)) {
        unique.add(item);
      }
    }
    return unique;
  }

  /// Total units in cart across all items.
  int get totalCount {
    if (_remoteCart != null) {
      return _remoteCart!.totalCount;
    }
    final seen = <String>{};
    return _localItems.values.where((i) => seen.add(i.id)).fold(0, (sum, i) => sum + i.quantity);
  }

  /// Total price payable in Rupees (Double for legacy UI widgets).
  double get totalPrice {
    if (_remoteCart != null) {
      return _remoteCart!.totalPayableInRupees;
    }
    final seen = <String>{};
    return _localItems.values.where((i) => seen.add(i.id)).fold(0.0, (sum, i) => sum + i.total);
  }

  /// Returns quantity of an item by line item ID, medicine ID, or cached slug.
  int quantityOf(String id) {
    if (_pendingQuantities.containsKey(id)) {
      return _pendingQuantities[id]!;
    }
    final mapped = _nameToObjectIdCache[id];
    if (mapped != null && _pendingQuantities.containsKey(mapped)) {
      return _pendingQuantities[mapped]!;
    }

    if (_remoteCart != null) {
      for (final item in _remoteCart!.items) {
        if (item.id == id || item.medicineId == id) {
          if (_pendingQuantities.containsKey(item.medicineId)) {
            return _pendingQuantities[item.medicineId]!;
          }
          if (_pendingQuantities.containsKey(item.id)) {
            return _pendingQuantities[item.id]!;
          }
          return item.quantity;
        }
      }
    }
    if (mapped != null && _remoteCart != null) {
      for (final item in _remoteCart!.items) {
        if (item.id == mapped || item.medicineId == mapped) {
          if (_pendingQuantities.containsKey(item.medicineId)) {
            return _pendingQuantities[item.medicineId]!;
          }
          if (_pendingQuantities.containsKey(item.id)) {
            return _pendingQuantities[item.id]!;
          }
          return item.quantity;
        }
      }
    }
    return _localItems[id]?.quantity ?? 0;
  }

  LoadStatus get status => _status;
  bool get isHydrating => _status == LoadStatus.hydrating || _isSyncingRemote;
  bool get userExplicitlyDetachedRx => _userExplicitlyDetachedRx;

  String? get prescriptionId {
    if (_remoteCart?.prescriptionId != null && _remoteCart!.prescriptionId!.trim().isNotEmpty) {
      return _remoteCart!.prescriptionId!.trim();
    }
    for (final id in _localPrescriptionIds) {
      if (id.trim().isNotEmpty) return id.trim();
    }
    return null;
  }

  String? get attachedPrescriptionName {
    if (_attachedPrescriptionName != null && _attachedPrescriptionName!.trim().isNotEmpty) {
      return _attachedPrescriptionName!.trim();
    }
    if (_remoteCart?.prescriptionDoctorName != null && _remoteCart!.prescriptionDoctorName!.trim().isNotEmpty) {
      return _remoteCart!.prescriptionDoctorName!.trim();
    }
    return null;
  }

  List<String> get prescriptionIds {
    if (_remoteCart?.prescriptionId != null && _remoteCart!.prescriptionId!.trim().isNotEmpty) {
      return [_remoteCart!.prescriptionId!.trim()];
    }
    return List.unmodifiable(_localPrescriptionIds.where((id) => id.trim().isNotEmpty));
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
    return _localPrescriptionIds.any((id) => id.trim().isNotEmpty);
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

  CartModel _overlayPendingQuantities(CartModel baseCart) {
    _pendingQuantities.removeWhere((key, targetQty) {
      if (_inFlightSyncs.contains(key) || _debounceTimers.containsKey(key)) {
        return false;
      }
      final cleanKey = key.startsWith('temp_') ? key.substring(5) : key;
      final mapped = _nameToObjectIdCache[key] ?? _nameToObjectIdCache[cleanKey];
      CartLineItem? match;
      for (final i in baseCart.items) {
        final iClean = i.id.startsWith('temp_') ? i.id.substring(5) : i.id;
        if (i.id == key ||
            i.id == cleanKey ||
            iClean == key ||
            iClean == cleanKey ||
            i.medicineId == key ||
            i.medicineId == cleanKey ||
            (mapped != null && (i.id == mapped || iClean == mapped || i.medicineId == mapped))) {
          match = i;
          break;
        }
      }
      if (match != null) {
        return match.quantity == targetQty;
      } else {
        return targetQty <= 0;
      }
    });

    if (_pendingQuantities.isEmpty) return baseCart;

    final items = List<CartLineItem>.from(baseCart.items);
    for (final entry in _pendingQuantities.entries) {
      final key = entry.key;
      final targetQty = entry.value;
      final cleanKey = key.startsWith('temp_') ? key.substring(5) : key;
      final mapped = _nameToObjectIdCache[key] ?? _nameToObjectIdCache[cleanKey];

      final index = items.indexWhere((i) {
        final iClean = i.id.startsWith('temp_') ? i.id.substring(5) : i.id;
        return i.id == key ||
            i.id == cleanKey ||
            iClean == key ||
            iClean == cleanKey ||
            i.medicineId == key ||
            i.medicineId == cleanKey ||
            (mapped != null && (i.id == mapped || iClean == mapped || i.medicineId == mapped));
      });

      if (index >= 0) {
        if (targetQty > 0) {
          items[index] = items[index].copyWith(quantity: targetQty);
        } else {
          items.removeAt(index);
        }
      } else if (targetQty > 0) {
        final fallback = _pendingFallbackItems[key] ??
            _pendingFallbackItems[cleanKey] ??
            _localItems[key] ??
            _localItems[cleanKey];
        if (fallback != null && fallback.name.trim().isNotEmpty && fallback.name != 'Medicine') {
          final pricePaise = ((fallback.price) * 100).round();
          items.add(CartLineItem(
            id: 'temp_$cleanKey',
            medicineId: _objectIdRegExp.hasMatch(cleanKey) ? cleanKey : (mapped ?? cleanKey),
            name: fallback.name,
            quantity: targetQty,
            pricePaise: pricePaise,
            mrpPaise: pricePaise,
            isPrescriptionRequired: fallback.requiresPrescription,
            packSize: fallback.pack,
          ));
        }
      }
    }

    final itemsTotal = items.fold<int>(0, (sum, i) => sum + (i.pricePaise * i.quantity));
    final deliveryFee = (items.isEmpty || itemsTotal >= 50000) ? 0 : 4000;
    final totalPayable = (itemsTotal - baseCart.discountPaise + deliveryFee).clamp(0, 999999999);

    return baseCart.copyWith(
      items: items,
      itemsTotalPaise: itemsTotal,
      deliveryFeePaise: deliveryFee,
      totalPayablePaise: totalPayable,
    );
  }

  void _applyRemoteCart(CartModel cart, {CartSummary? summary, List<CartWarning>? warnings}) {
    CartModel effectiveCart = cart;
    if (_pendingQuantities.isNotEmpty) {
      effectiveCart = _overlayPendingQuantities(cart);
    }

    // A cart converted to an order or abandoned is no longer an active customer cart
    final cartStatus = effectiveCart.status.toUpperCase();
    if (cartStatus == 'ORDER_PLACED' || cartStatus == 'ABANDONED') {
      _localItems.clear();
      _localPrescriptionIds.clear();
      _remoteCart = null;
      _summary = const CartSummary();
      _warnings = const [];
      _stockHoldTimer?.cancel();
      _remainingHoldSeconds = 0;
      _schedulePersist();
      _safeNotify();
      return;
    }

    // If backend returns null prescription (happens on qty PATCH / other partial updates),
    // preserve the previously attached prescription so the cart never accidentally loses it.
    final incomingRxId = effectiveCart.prescriptionId;
    final hadRxBefore = (_remoteCart?.prescriptionId != null && _remoteCart!.prescriptionId!.isNotEmpty) ||
        _localPrescriptionIds.any((id) => id.trim().isNotEmpty);
    final backendDroppedRx = (incomingRxId == null || incomingRxId.isEmpty) && hadRxBefore && !_userExplicitlyDetachedRx;

    if (backendDroppedRx) {
      // Rehydrate the previously known prescription ID back into the incoming cart
      final preservedRxId = _remoteCart?.prescriptionId ?? _localPrescriptionIds.firstWhere((id) => id.trim().isNotEmpty, orElse: () => '');
      if (preservedRxId.isNotEmpty) {
        effectiveCart = effectiveCart.copyWith(
          prescriptionId: preservedRxId,
          prescriptionDoctorName: _attachedPrescriptionName ?? _remoteCart?.prescriptionDoctorName,
        );
        debugPrint('[CartNotifier] Preserved prescriptionId=$preservedRxId (backend returned null on partial update)');
      }
    }

    _remoteCart = effectiveCart;
    if (summary != null) _summary = summary;
    if (warnings != null) _warnings = warnings;

    if (effectiveCart.allocatedStore != null && effectiveCart.allocatedStore!.isNotEmpty) {
      _allocatedStoreId = effectiveCart.allocatedStore;
    }

    // Mirror to local cache for offline persistence
    _localItems.clear();
    for (final item in effectiveCart.items) {
      _localItems[item.id] = item.toCartItem();
      if (item.medicineId.isNotEmpty) {
        _localItems[item.medicineId] = item.toCartItem();
      }
    }
    if (effectiveCart.prescriptionId != null && effectiveCart.prescriptionId!.isNotEmpty) {
      _localPrescriptionIds.clear();
      _localPrescriptionIds.add(effectiveCart.prescriptionId!);
    } else if (effectiveCart.prescriptionId == '' || _userExplicitlyDetachedRx) {
      _localPrescriptionIds.clear();
    }

    if (effectiveCart.isLocked && effectiveCart.expiresAt != null) {
      final isExpired = effectiveCart.expiresAt!.isBefore(DateTime.now().toUtc());
      if (isExpired) {
        _stockHoldTimer?.cancel();
        _remainingHoldSeconds = 0;
      } else {
        _startHoldTimer(effectiveCart.expiresAt!);
      }
    } else {
      _stockHoldTimer?.cancel();
      _remainingHoldSeconds = 0;
    }

    _schedulePersist();
    _safeNotify();
  }

  void _applyOptimisticUpdate(String key, int newQuantity, {CartItem? fallback}) {
    final cleanKey = key.startsWith('temp_') ? key.substring(5) : key;
    final mapped = _nameToObjectIdCache[key] ?? _nameToObjectIdCache[cleanKey];
    final resolvedMedicineId = _objectIdRegExp.hasMatch(cleanKey)
        ? cleanKey
        : (mapped ?? (fallback != null && _objectIdRegExp.hasMatch(fallback.id) ? fallback.id : cleanKey));

    final effectiveFallback = fallback ??
        _pendingFallbackItems[key] ??
        _pendingFallbackItems[cleanKey] ??
        _localItems[key] ??
        _localItems[cleanKey];

    if (newQuantity > 0) {
      if (effectiveFallback != null &&
          effectiveFallback.name.trim().isNotEmpty &&
          effectiveFallback.name != 'Medicine') {
        final updated = effectiveFallback.copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now().toUtc(),
        );
        _localItems[key] = updated;
        _localItems[cleanKey] = updated;
      } else if (_localItems.containsKey(key)) {
        _localItems[key] = _localItems[key]!.copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now().toUtc(),
        );
      } else if (_localItems.containsKey(cleanKey)) {
        _localItems[cleanKey] = _localItems[cleanKey]!.copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now().toUtc(),
        );
      }
    } else {
      _localItems.remove(key);
      _localItems.remove(cleanKey);
      if (mapped != null) _localItems.remove(mapped);
      _localItems.removeWhere((k, v) =>
          v.id == key ||
          v.id == cleanKey ||
          (v is CartLineItem && (v.medicineId == key || v.medicineId == cleanKey)));
    }

    if (_remoteCart != null) {
      final items = List<CartLineItem>.from(_remoteCart!.items);

      final index = items.indexWhere((i) {
        final iClean = i.id.startsWith('temp_') ? i.id.substring(5) : i.id;
        return i.id == key ||
            i.id == cleanKey ||
            iClean == key ||
            iClean == cleanKey ||
            i.medicineId == key ||
            i.medicineId == cleanKey ||
            i.medicineId == resolvedMedicineId ||
            (mapped != null &&
                (i.id == mapped ||
                    iClean == mapped ||
                    i.medicineId == mapped));
      });

      if (index >= 0) {
        if (newQuantity > 0) {
          items[index] = items[index].copyWith(quantity: newQuantity);
        } else {
          items.removeAt(index);
        }
      } else if (newQuantity > 0) {
        if (effectiveFallback != null &&
            effectiveFallback.name.trim().isNotEmpty &&
            effectiveFallback.name != 'Medicine') {
          final pricePaise = ((effectiveFallback.price) * 100).round();
          items.add(CartLineItem(
            id: 'temp_$cleanKey',
            medicineId: resolvedMedicineId,
            name: effectiveFallback.name,
            quantity: newQuantity,
            pricePaise: pricePaise,
            mrpPaise: pricePaise,
            isPrescriptionRequired: effectiveFallback.requiresPrescription,
            packSize: effectiveFallback.pack,
          ));
        } else if (fallback != null) {
          final pricePaise = ((fallback.price) * 100).round();
          items.add(CartLineItem(
            id: 'temp_$cleanKey',
            medicineId: resolvedMedicineId,
            name: fallback.name.isNotEmpty ? fallback.name : 'Medicine',
            quantity: newQuantity,
            pricePaise: pricePaise,
            mrpPaise: pricePaise,
            isPrescriptionRequired: fallback.requiresPrescription,
            packSize: fallback.pack,
          ));
        }
      }

      final itemsTotal = items.fold<int>(0, (sum, i) => sum + (i.pricePaise * i.quantity));
      final deliveryFee = (items.isEmpty || itemsTotal >= 50000) ? 0 : 4000;
      final totalPayable = (itemsTotal - _remoteCart!.discountPaise + deliveryFee).clamp(0, 999999999);

      _remoteCart = _remoteCart!.copyWith(
        items: items,
        itemsTotalPaise: itemsTotal,
        deliveryFeePaise: deliveryFee,
        totalPayablePaise: totalPayable,
      );
    }

    _schedulePersist();
    _safeNotify();
  }

  void _scheduleDebouncedSync(String key, {CartItem? fallback}) {
    if (fallback != null) {
      _pendingFallbackItems[key] = fallback;
    }

    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(_debounceDuration, () {
      _debounceTimers.remove(key);
      _executeSync(key);
    });
  }

  Future<void> _executeSync(String key) async {
    if (_disposed) return;
    if (_inFlightSyncs.contains(key)) return;

    if (!_pendingQuantities.containsKey(key)) return;
    final targetQty = _pendingQuantities[key]!;
    debugPrint('[CartNotifier._executeSync] key=$key, targetQty=$targetQty');

    if (_repository == null || ApiService.token == null) {
      debugPrint('[CartNotifier._executeSync] SKIP: repo=${_repository != null}, token=${ApiService.token != null}');
      _pendingQuantities.remove(key);
      return;
    }

    CartLineItem? remoteItem;
    final mapped = _nameToObjectIdCache[key];
    final cleanKey = key.startsWith('temp_') ? key.substring(5) : key;

    if (_remoteCart != null) {
      debugPrint('[CartNotifier._executeSync] Searching ${_remoteCart!.items.length} remote items for key=$key, cleanKey=$cleanKey, mapped=$mapped');
      for (final r in _remoteCart!.items) {
        final rClean = r.id.startsWith('temp_') ? r.id.substring(5) : r.id;
        if (r.id == key ||
            r.id == cleanKey ||
            rClean == key ||
            rClean == cleanKey ||
            r.medicineId == key ||
            r.medicineId == cleanKey ||
            (mapped != null && (r.id == mapped || rClean == mapped || r.medicineId == mapped))) {
          remoteItem = r;
          debugPrint('[CartNotifier._executeSync] FOUND remoteItem: id=${r.id}, medicineId=${r.medicineId}, qty=${r.quantity}');
          break;
        }
      }
      if (remoteItem == null) {
        debugPrint('[CartNotifier._executeSync] NO MATCH found. Remote items:');
        for (final r in _remoteCart!.items) {
          debugPrint('  - id=${r.id}, medicineId=${r.medicineId}, name=${r.name}');
        }
      }
    } else {
      debugPrint('[CartNotifier._executeSync] _remoteCart is null');
    }

    bool syncSucceeded = false;
    _inFlightSyncs.add(key);
    _actionError = null;

    try {
      final bool isRealRemoteItem = remoteItem != null && !remoteItem.id.startsWith('temp_');

      if (isRealRemoteItem) {
        // Real line item in cart on server
        final apiId = remoteItem.id;
        if (targetQty > 0) {
          // Always PATCH when we have a pending quantity — the optimistic update
          // already set remoteItem.quantity to targetQty locally, so comparing
          // against it would always skip the network call.
          debugPrint('[CartNotifier._executeSync] PATCH updateRemoteQuantity(apiId=$apiId, qty=$targetQty)');
          try {
            final updatedCart = await _repository.updateRemoteQuantity(apiId, targetQty);
            if (updatedCart != null) {
              syncSucceeded = true;
              _applyRemoteCart(updatedCart);
            }
          } catch (e) {
            // Self-healing: If server returns 404 (item not found in cart), attempt to add it
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('not found') || errorStr.contains('404')) {
              debugPrint('[CartNotifier._executeSync] Item $apiId not found in cart on server. Falling back to addRemoteItem.');
              final medId = (remoteItem.medicineId.isNotEmpty && _objectIdRegExp.hasMatch(remoteItem.medicineId))
                  ? remoteItem.medicineId
                  : cleanKey;
              final updatedCart = await _repository.addRemoteItem(medId, targetQty);
              if (updatedCart != null) {
                syncSucceeded = true;
                _applyRemoteCart(updatedCart);
              }
            } else {
              rethrow;
            }
          }
        } else {
          debugPrint('[CartNotifier._executeSync] DELETE removeRemoteItem(apiId=$apiId)');
          final updatedCart = await _repository.removeRemoteItem(apiId);
          if (updatedCart != null) {
            syncSucceeded = true;
            _applyRemoteCart(updatedCart);
          }
        }
      } else {
        // Item is not yet in cart on the server (remoteItem is null or has temporary optimistic ID)
        if (targetQty > 0) {
          String resolvedId = cleanKey;
          if (remoteItem != null && remoteItem.medicineId.isNotEmpty && _objectIdRegExp.hasMatch(remoteItem.medicineId)) {
            resolvedId = remoteItem.medicineId;
          }
          final fallback = _pendingFallbackItems[key] ?? _pendingFallbackItems[cleanKey];

          if (!_objectIdRegExp.hasMatch(resolvedId)) {
            final cached = _nameToObjectIdCache[key] ??
                _nameToObjectIdCache[cleanKey] ??
                _nameToObjectIdCache[fallback?.name ?? ''];
            if (cached != null) {
              resolvedId = cached;
            } else {
              try {
                final targetName = (fallback?.name ?? key).trim().toLowerCase();
                final query = targetName.replaceAll('_', ' ').split(' ').first;
                final matches = await ApiService.searchMedicines(search: query);
                for (final m in matches) {
                  final rawCand = m['_id'] ?? m['id'] ?? m['medicineId'];
                  final candidate = (rawCand is Map)
                      ? (rawCand[r'$oid'] ?? rawCand['_id'] ?? rawCand['id'])?.toString()
                      : rawCand?.toString();
                  final candName = (m['name'] as String? ?? '').trim().toLowerCase();
                  if (candidate != null && _objectIdRegExp.hasMatch(candidate)) {
                    final isNameMatch = candName == targetName ||
                        (candName.isNotEmpty &&
                            targetName.isNotEmpty &&
                            (candName.contains(query) || targetName.contains(candName)));
                    if (isNameMatch) {
                      resolvedId = candidate;
                      _nameToObjectIdCache[key] = candidate;
                      _nameToObjectIdCache[cleanKey] = candidate;
                      if (fallback?.name != null) {
                        _nameToObjectIdCache[fallback!.name] = candidate;
                      }
                      break;
                    }
                  }
                }
              } catch (_) {}
            }
          }

          if (_objectIdRegExp.hasMatch(resolvedId) || (!resolvedId.contains('-') && !resolvedId.contains(' ') && !resolvedId.contains('_forte'))) {
            debugPrint('[CartNotifier._executeSync] POST addRemoteItem(resolvedId=$resolvedId, qty=$targetQty)');
            final updatedCart = await _repository.addRemoteItem(resolvedId, targetQty);
            if (updatedCart != null) {
              syncSucceeded = true;
              _applyRemoteCart(updatedCart);
            }
          }
        } else {
          // targetQty <= 0 and item was never added to server cart
          syncSucceeded = true;
          _pendingQuantities.remove(key);
          _pendingQuantities.remove(cleanKey);
          _pendingFallbackItems.remove(key);
          _pendingFallbackItems.remove(cleanKey);
        }
      }
    } catch (e) {
      debugPrint('[CartNotifier] Debounced sync error for $key: $e');
      _actionError = e.toString();
      _safeNotify();
    } finally {
      _inFlightSyncs.remove(key);

      if (_pendingQuantities.containsKey(key)) {
        final latestTarget = _pendingQuantities[key]!;
        if (latestTarget != targetQty) {
          debugPrint('[CartNotifier._executeSync] Target changed during sync ($targetQty -> $latestTarget). Scheduling sync for new target.');
          _scheduleDebouncedSync(key);
        } else if (syncSucceeded) {
          _pendingQuantities.remove(key);
          _pendingFallbackItems.remove(key);
        } else {
          _pendingQuantities.remove(key);
        }
      }
    }
  }

  // ── 11 Cart & Checkout REST API Integrations ──────────────────────────────

  bool _isSyncingRemote = false;

  /// 1. Sync active customer cart with live catalogue pricing and summary flags
  Future<void> syncRemoteCart() async {
    if (_isSyncingRemote || _repository == null || ApiService.token == null) return;
    _isSyncingRemote = true;
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
    } finally {
      _isSyncingRemote = false;
    }
  }

  /// 2. Add item to cart via API (medicineId, quantity: 1..50) with debouncing & optimistic UI
  Future<void> addMedicine(String medicineId, {int quantity = 1, CartItem? localFallback}) async {
    final key = medicineId;
    if (localFallback != null && localFallback.name.isNotEmpty && _objectIdRegExp.hasMatch(key)) {
      _nameToObjectIdCache[localFallback.name] = key;
    }

    final currentQty = quantityOf(key);
    final targetQty = (currentQty + quantity).clamp(1, 50);

    final cleanKey = key.startsWith('temp_') ? key.substring(5) : key;
    final fallback = localFallback ??
        _pendingFallbackItems[key] ??
        _pendingFallbackItems[cleanKey] ??
        _localItems[key] ??
        _localItems[cleanKey] ??
        CartItem(id: key, name: key, pack: '1 Unit', price: 0, quantity: targetQty);

    _pendingQuantities[key] = targetQty;
    _pendingFallbackItems[key] = fallback;

    _applyOptimisticUpdate(key, targetQty, fallback: fallback);
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
    await _executeSync(key);
  }

  /// 3. Update quantity of existing cart line item (lineItemId: _id, quantity: 1..50) with debouncing
  Future<void> updateItemQuantity(String lineItemId, int newQuantity) async {
    final key = lineItemId;
    final targetQty = newQuantity.clamp(0, 50);

    _pendingQuantities[key] = targetQty;
    _applyOptimisticUpdate(key, targetQty);
    _scheduleDebouncedSync(key);
  }

  /// 4. Remove a line item from active cart by line item _id with debouncing
  Future<void> removeCartItem(String lineItemId) async {
    final key = lineItemId;
    _pendingQuantities[key] = 0;
    _applyOptimisticUpdate(key, 0);
    _scheduleDebouncedSync(key);
  }

  /// 5. Clear entire cart
  Future<void> clearAll() async {
    _actionError = null;
    _allocatedStoreId = null;
    _storeAllocationMessage = null;
    _stockHoldTimer?.cancel();
    _remainingHoldSeconds = 0;

    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingQuantities.clear();
    _pendingFallbackItems.clear();
    _inFlightSyncs.clear();

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
  Future<bool> attachPrescriptionId(String prescriptionId, {String? prescriptionName}) async {
    final cleanId = prescriptionId.trim();
    if (cleanId.isEmpty) return false;

    _userExplicitlyDetachedRx = false;
    _actionError = null;
    if (prescriptionName != null && prescriptionName.trim().isNotEmpty) {
      _attachedPrescriptionName = prescriptionName.trim();
    }

    // Immediately record locally so UI updates and customer is never stuck
    _localPrescriptionIds.clear();
    _localPrescriptionIds.add(cleanId);
    if (_remoteCart != null) {
      _remoteCart = _remoteCart!.copyWith(
        prescriptionId: cleanId,
        prescriptionDoctorName: _attachedPrescriptionName,
      );
    }
    _schedulePersist();
    _safeNotify();

    if (ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.attachPrescriptionRemote(cleanId);
        if (updatedCart != null) {
          final resolvedCart = (updatedCart.prescriptionId == null || updatedCart.prescriptionId!.isEmpty)
              ? updatedCart.copyWith(
                  prescriptionId: cleanId,
                  prescriptionDoctorName: _attachedPrescriptionName ?? updatedCart.prescriptionDoctorName,
                )
              : updatedCart.copyWith(
                  prescriptionDoctorName: _attachedPrescriptionName ?? updatedCart.prescriptionDoctorName,
                );
          _applyRemoteCart(resolvedCart);
          return true;
        }
      } catch (e) {
        _actionError = e.toString();
        debugPrint('[CartNotifier] attachPrescriptionRemote error: $e');
        if (_remoteCart != null) {
          _remoteCart = _remoteCart!.copyWith(
            prescriptionId: cleanId,
            prescriptionDoctorName: _attachedPrescriptionName,
          );
        }
        _safeNotify();
        return true;
      }
    }

    return true;
  }

  /// 8. Remove attached prescription from active cart
  Future<bool> removePrescriptionId() async {
    _userExplicitlyDetachedRx = true;
    _actionError = null;
    _attachedPrescriptionName = null;
    _actionError = null;

    // Immediately clear local optimistic state
    _localPrescriptionIds.clear();
    if (_remoteCart != null) {
      _remoteCart = _remoteCart!.copyWith(prescriptionId: '');
    }
    _schedulePersist();
    _safeNotify();

    if (ApiService.token != null && _repository != null) {
      try {
        final updatedCart = await _repository.removePrescriptionRemote();
        if (updatedCart != null) {
          final clearedCart = updatedCart.copyWith(prescriptionId: '');
          _applyRemoteCart(clearedCart);
          return true;
        }
      } catch (e) {
        _actionError = e.toString();
        debugPrint('[CartNotifier] removePrescriptionRemote error: $e');
        _safeNotify();
      }
    }

    return true;
  }

  /// 9. Apply promotional coupon code (e.g. WELCOME50, SAVE10)
  Future<bool> applyCouponCode(String code) async {
    _isApplyingCoupon = true;
    _actionError = null;
    _safeNotify();

    try {
      if (ApiService.token != null && _repository != null) {
        // Guarantee all pending quantity syncs are flushed to the server before validating coupon
        for (final key in _debounceTimers.keys.toList()) {
          _debounceTimers[key]?.cancel();
          _debounceTimers.remove(key);
          await _executeSync(key);
        }

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
      _actionError = e is Failure
          ? e.message
          : e.toString().replaceAll('ValidationFailure: ', '').replaceAll('Exception: ', '');
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
    final key = item.id;
    debugPrint('[CartNotifier.add] key=$key, item.name=${item.name}, item.medicineId=${item is CartLineItem ? item.medicineId : "N/A"}');
    if (item.name.isNotEmpty && _objectIdRegExp.hasMatch(key)) {
      _nameToObjectIdCache[item.name] = key;
    }

    final currentQty = quantityOf(key);
    if (currentQty >= 50) return;

    final newQty = (currentQty == 0 && item.quantity > 1)
        ? item.quantity.clamp(1, 50)
        : (currentQty + 1).clamp(1, 50);
    debugPrint('[CartNotifier.add] currentQty=$currentQty, newQty=$newQty');
    _pendingQuantities[key] = newQty;
    _pendingFallbackItems[key] = item;

    _applyOptimisticUpdate(key, newQty, fallback: item);
    _scheduleDebouncedSync(key, fallback: item);
  }

  void remove(String id) {
    final key = id;
    final currentQty = quantityOf(key);
    if (currentQty <= 0) return;

    final newQty = currentQty - 1;
    _pendingQuantities[key] = newQty;

    final cleanKey = key.startsWith('temp_') ? key.substring(5) : key;
    final fallback = _pendingFallbackItems[key] ??
        _pendingFallbackItems[cleanKey] ??
        _localItems[key] ??
        _localItems[cleanKey];

    if (fallback != null) {
      _pendingFallbackItems[key] = fallback;
    }

    _applyOptimisticUpdate(key, newQty, fallback: fallback);
    _scheduleDebouncedSync(key, fallback: fallback);
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

  // ── Lifecycle & Hydration ──────────────────────────────────────────────────
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

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;

    scheduleMicrotask(() async {
      if (_disposed) return;
      await init();
    });
  }

  Future<void> refresh() async {
    await syncRemoteCart();
  }

  void reset() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingQuantities.clear();
    _pendingFallbackItems.clear();
    _inFlightSyncs.clear();

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
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingQuantities.clear();
    _pendingFallbackItems.clear();
    _inFlightSyncs.clear();

    _stockHoldTimer?.cancel();
    super.dispose();
  }
}
