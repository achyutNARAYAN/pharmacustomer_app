import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/providers/load_status.dart';
import '../repositories/orders_repository.dart';

class OrdersProvider extends ChangeNotifier {
  final OrdersRepository? _repository;
  final List<OrderItem> _orders = [];

  String? _userId;
  LoadStatus _status = LoadStatus.uninitialized;
  bool _disposed = false;

  OrdersProvider([this._repository, List<OrderItem>? initial]) {
    if (initial != null) {
      _orders.addAll(initial);
      _status = LoadStatus.ready;
    }
  }

  List<OrderItem> get orders => List.unmodifiable(_orders);
  int get activeCount => _orders.where((o) => o.isActive).length;
  LoadStatus get status => _status;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void addOrder(OrderItem order) {
    _orders.insert(0, order);
    if (_repository != null && _userId != null) {
      _repository.schedulePersist(_userId!, _orders);
    }
    _safeNotify();
  }

  Future<void> init() async {
    if (_repository == null || _userId == null) {
      _status = LoadStatus.ready;
      _safeNotify();
      return;
    }

    _status = LoadStatus.hydrating;
    _safeNotify();

    final loaded = await _repository.hydrate(_userId!);
    _orders.clear();
    _orders.addAll(loaded);

    _status = LoadStatus.ready;
    _safeNotify();
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
    await init();
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
