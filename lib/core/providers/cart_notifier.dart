import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../../features/cart/models/cart_snapshot.dart';
import '../../features/cart/repositories/cart_repository.dart';
import 'load_status.dart';

class CartNotifier extends ChangeNotifier implements PersistedProvider {
  final CartRepository? _repository;
  final Map<String, CartItem> _items = {};
  final List<String> _prescriptionIds = [];

  String? _userId;
  LoadStatus _status = LoadStatus.uninitialized;
  bool _disposed = false;

  CartNotifier([this._repository, CartSnapshot? initial]) {
    if (initial != null) {
      for (final item in initial.lines) {
        _items[item.id] = item;
      }
      _prescriptionIds.addAll(initial.prescriptionIds);
      _status = LoadStatus.ready;
    }
  }

  // ── Existing Public API (Kept 100% Identical) ──────────────────────────────
  List<CartItem> get items => _items.values.toList();

  int get totalCount => _items.values.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice => _items.values.fold(0.0, (sum, i) => sum + i.total);

  int quantityOf(String id) => _items[id]?.quantity ?? 0;

  // ── New & Derived Getters ─────────────────────────────────────────────────
  LoadStatus get status => _status;
  List<String> get prescriptionIds => List.unmodifiable(_prescriptionIds);
  bool get hasRxLines => _items.values.any((i) => i.requiresPrescription);
  bool get hasPrescriptionAttached => _prescriptionIds.isNotEmpty;
  int get lineCount => _items.length;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _schedulePersist() {
    if (_repository != null) {
      final snapshot = CartSnapshot(
        lines: _items.values.toList(),
        prescriptionIds: _prescriptionIds,
      );
      _repository.schedulePersist(_userId, snapshot);
    }
  }

  // ── Existing Mutations (Extended with Persistence) ────────────────────────
  void add(CartItem item) {
    final now = DateTime.now().toUtc();
    if (_items.containsKey(item.id)) {
      final current = _items[item.id]!;
      if (current.quantity < 10) {
        current.quantity++;
        _items[item.id] = current.copyWith(
          quantity: current.quantity,
          updatedAt: now,
        );
        _schedulePersist();
        _safeNotify();
      }
    } else {
      _items[item.id] = item.copyWith(
        quantity: item.quantity,
        addedAt: now,
        updatedAt: now,
      );
      _schedulePersist();
      _safeNotify();
    }
  }

  void remove(String id) {
    if (!_items.containsKey(id)) return;
    final now = DateTime.now().toUtc();
    if (_items[id]!.quantity > 1) {
      final current = _items[id]!;
      current.quantity--;
      _items[id] = current.copyWith(
        quantity: current.quantity,
        updatedAt: now,
      );
    } else {
      _items.remove(id);
    }
    _schedulePersist();
    _safeNotify();
  }

  void clear() {
    _items.clear();
    _prescriptionIds.clear();
    _schedulePersist();
    _safeNotify();
  }

  // ── Prescription Linking ──────────────────────────────────────────────────
  void attachPrescription(String prescriptionId) {
    if (!_prescriptionIds.contains(prescriptionId)) {
      _prescriptionIds.add(prescriptionId);
      _schedulePersist();
      _safeNotify();
    }
  }

  void detachPrescription(String prescriptionId) {
    if (_prescriptionIds.remove(prescriptionId)) {
      _schedulePersist();
      _safeNotify();
    }
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
    _items.clear();
    for (final item in snapshot.lines) {
      _items[item.id] = item;
    }
    _prescriptionIds.clear();
    _prescriptionIds.addAll(snapshot.prescriptionIds);

    _status = LoadStatus.ready;
    _safeNotify();
  }

  @override
  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;

    // Must never notify synchronously inside ProxyProvider.update!
    scheduleMicrotask(() async {
      if (_disposed) return;
      await init();
    });
  }

  @override
  Future<void> refresh() async {
    // Network refresh if remote cart endpoint is available
    if (_repository != null && _userId != null) {
      try {
        final serverCart = await _repository.fetchRemoteCart();
        if (serverCart != null) {
          _items.clear();
          for (final item in serverCart.lines) {
            _items[item.id] = item;
          }
          _prescriptionIds.clear();
          _prescriptionIds.addAll(serverCart.prescriptionIds);
          _safeNotify();
        }
      } catch (_) {
        // Stale-while-revalidate: keep local cache on failure
      }
    }
  }

  @override
  void reset() {
    _items.clear();
    _prescriptionIds.clear();
    _status = LoadStatus.ready;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
