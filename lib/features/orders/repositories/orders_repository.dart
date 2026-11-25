import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../core/storage/key_value_store.dart';
import '../models/order_model.dart';

export '../models/order_model.dart';

class OrdersRepository {
  final KeyValueStore store;

  OrdersRepository({
    required this.store,
  });

  String keyFor(String userId) => 'orders.$userId';

  /// 1. Hydrate cached orders from local device storage
  Future<List<OrderModel>> hydrate(String userId) async {
    try {
      final key = keyFor(userId);
      final raw = await store.read(key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return [];

      final data = decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;

      final rawList = data['orders'];
      if (rawList is! List) return [];

      final orders = <OrderModel>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          try {
            orders.add(OrderModel.fromJson(item));
          } catch (_) {}
        }
      }
      return orders;
    } catch (_) {
      return [];
    }
  }

  /// 2. Persist orders to local disk
  void schedulePersist(String userId, List<OrderModel> orders) {
    final key = keyFor(userId);
    store.write(
      key,
      jsonEncode({
        'orders': orders.take(20).map((o) => o.toJson()).toList(),
      }),
    );
  }

  /// 3. Fetch remote orders from production API (GET /api/v1/orders)
  Future<List<OrderModel>> fetchRemoteOrders({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    try {
      final res = await ApiService.getOrders(
        page: page,
        limit: limit,
        status: status,
        search: search,
      );

      final List<dynamic> list;
      if (res is List) {
        list = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        list = res['data'] as List;
      } else {
        return [];
      }

      final orders = <OrderModel>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            orders.add(OrderModel.fromJson(item));
          } catch (_) {}
        }
      }
      return orders;
    } catch (e) {
      rethrow;
    }
  }

  /// 4. Fetch specific order details (GET /api/v1/orders/:orderId)
  Future<OrderModel?> fetchOrderDetails(String orderId) async {
    try {
      final res = await ApiService.getOrderDetails(orderId);
      if (res is Map<String, dynamic>) {
        final data = res.containsKey('data') && res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        return OrderModel.fromJson(data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// 5. Place real order (POST /api/v1/orders)
  Future<OrderModel> placeOrder({
    required String paymentMethod,
    String? customerNote,
    String? cartId,
  }) async {
    final res = await ApiService.placeOrder(
      paymentMethod: paymentMethod,
      customerNote: customerNote,
      cartId: cartId,
    );
    if (res is Map<String, dynamic>) {
      final data = res.containsKey('data') && res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return OrderModel.fromJson(data);
    }
    throw Exception('Invalid order response from server');
  }

  /// 6. Cancel order (POST /api/v1/orders/:orderId/cancel)
  Future<bool> cancelOrder({
    required String orderId,
    required String reason,
    String? note,
  }) async {
    final res = await ApiService.cancelOrder(
      orderId: orderId,
      reason: reason,
      note: note,
    );
    return res != null;
  }

  Future<void> clearOrders(String userId) async {
    await store.remove(keyFor(userId));
  }

  Future<void> wipeUser(String userId) async {
    await store.remove(keyFor(userId));
  }
}
