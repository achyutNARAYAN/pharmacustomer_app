import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/providers/load_status.dart';
import '../../../core/services/api_service.dart';
import '../repositories/orders_repository.dart';

export '../models/order_model.dart';

class OrdersProvider extends ChangeNotifier {
  final OrdersRepository? _repository;
  final List<OrderModel> _orders = [];

  String? _userId;
  LoadStatus _status = LoadStatus.uninitialized;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  OrdersProvider([this._repository, List<OrderModel>? initial]) {
    if (initial != null) {
      _orders.addAll(initial);
      _status = LoadStatus.ready;
    }
  }

  List<OrderModel> get orders => List.unmodifiable(_orders);
  int get activeCount => _orders.where((o) => o.isActive).length;
  LoadStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void addOrder(OrderModel order) {
    _orders.removeWhere((o) => o.id == order.id || o.orderCode == order.orderCode);
    _orders.insert(0, order);
    final repo = _repository;
    final uid = _userId;
    if (repo != null && uid != null) {
      repo.schedulePersist(uid, _orders);
    }
    _safeNotify();
  }

  Future<void> init() async {
    final repo = _repository;
    final uid = _userId;
    if (repo == null || uid == null) {
      _status = LoadStatus.ready;
      _safeNotify();
      return;
    }

    _status = LoadStatus.hydrating;
    _safeNotify();

    // 1. Hydrate local cache
    final loaded = await repo.hydrate(uid);
    _orders.clear();
    _orders.addAll(loaded);

    _status = LoadStatus.ready;
    _safeNotify();

    // 2. Refresh remote orders in background
    await syncRemoteOrders();
  }

  Future<void> syncRemoteOrders({String? filterStatus, String? search, bool silent = false}) async {
    final repo = _repository;
    if (repo == null || ApiService.token == null) return;
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      _safeNotify();
    }

    try {
      final remoteOrders = await repo.fetchRemoteOrders(
        status: filterStatus,
        search: search,
      );
      if (filterStatus == null && (search == null || search.isEmpty)) {
        _orders.clear();
        _orders.addAll(remoteOrders);
        final uid = _userId;
        if (uid != null) {
          repo.schedulePersist(uid, _orders);
        }
      }
      _status = LoadStatus.ready;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!silent) {
        _isLoading = false;
        _safeNotify();
      } else {
        _safeNotify();
      }
    }
  }

  Future<void> fetchOrders({bool silent = false}) async {
    await syncRemoteOrders(silent: silent);
  }

  Future<OrderModel> placeOrder({
    required String paymentMethod,
    String? customerNote,
    String? cartId,
  }) async {
    final repo = _repository;
    if (repo == null) {
      throw Exception('OrdersRepository not initialized');
    }
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final newOrder = await repo.placeOrder(
        paymentMethod: paymentMethod,
        customerNote: customerNote,
        cartId: cartId,
      );
      addOrder(newOrder);
      return newOrder;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<OrderModel?> getOrderDetails(String orderId) async {
    final repo = _repository;
    if (repo == null) return null;
    try {
      final updated = await repo.fetchOrderDetails(orderId);
      if (updated != null) {
        final idx = _orders.indexWhere((o) => o.id == updated.id || o.orderCode == updated.orderCode);
        if (idx != -1) {
          _orders[idx] = updated;
        } else {
          _orders.insert(0, updated);
        }
        final uid = _userId;
        if (uid != null) {
          repo.schedulePersist(uid, _orders);
        }
        _safeNotify();
      }
      return updated;
    } catch (_) {
      return null;
    }
  }

  Future<bool> cancelOrder({
    required String orderId,
    required String reason,
    String? note,
  }) async {
    final repo = _repository;
    if (repo == null) return false;

    // 1. Instant Optimistic Local Update
    final idx = _orders.indexWhere((o) => o.id == orderId || o.orderCode == orderId);
    OrderModel? originalOrder;
    if (idx != -1) {
      originalOrder = _orders[idx];
      _orders[idx] = originalOrder.copyWith(
        status: OrderStatus.CANCELLED,
        cancellationReason: reason,
        cancelledAt: DateTime.now(),
      );
      final uid = _userId;
      if (uid != null) {
        repo.schedulePersist(uid, _orders);
      }
      _safeNotify();
    }

    try {
      final effectiveId = (originalOrder != null && originalOrder.id.isNotEmpty)
          ? originalOrder.id
          : orderId;

      final success = await repo.cancelOrder(
        orderId: effectiveId,
        reason: reason,
        note: note,
      );

      // 2. Refresh authoritative list from server silently
      await syncRemoteOrders(silent: true);
      return success;
    } catch (e) {
      // Revert optimistic update on failure
      if (idx != -1 && originalOrder != null) {
        _orders[idx] = originalOrder;
        _safeNotify();
      }
      _errorMessage = e.toString();
      _safeNotify();
      rethrow;
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
    await syncRemoteOrders();
  }

  Future<void> clearAll() async {
    _orders.clear();
    final repo = _repository;
    final uid = _userId;
    if (repo != null && uid != null) {
      await repo.clearOrders(uid);
    }
    _safeNotify();
  }

  void reset() {
    _orders.clear();
    _status = LoadStatus.ready;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
