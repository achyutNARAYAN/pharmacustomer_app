import 'dart:convert';
import '../../../core/storage/key_value_store.dart';

enum OrderStatus {
  placed,
  confirmed,
  processing,
  outForDelivery,
  delivered,
  cancelled,
  rejected,
  refunded,
}

class OrderItem {
  final String orderId;
  final OrderStatus status;
  final int totalPaise;
  final int itemCount;
  final DateTime createdAt;

  const OrderItem({
    required this.orderId,
    required this.status,
    required this.totalPaise,
    required this.itemCount,
    required this.createdAt,
  });

  bool get isActive =>
      status != OrderStatus.delivered &&
      status != OrderStatus.cancelled &&
      status != OrderStatus.rejected &&
      status != OrderStatus.refunded;

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'status': status.name,
        'totalPaise': totalPaise,
        'itemCount': itemCount,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static OrderItem? fromJson(Map<String, dynamic> json) {
    final orderId = json['orderId'];
    final statusName = json['status'];
    final totalPaise = json['totalPaise'];
    final itemCount = json['itemCount'];
    final createdAtRaw = json['createdAt'];

    if (orderId is! String ||
        statusName is! String ||
        totalPaise is! int ||
        itemCount is! int ||
        createdAtRaw is! String) {
      return null;
    }

    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;

    final status = OrderStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => OrderStatus.placed,
    );

    return OrderItem(
      orderId: orderId,
      status: status,
      totalPaise: totalPaise,
      itemCount: itemCount,
      createdAt: createdAt,
    );
  }
}

class OrdersRepository {
  final KeyValueStore store;

  OrdersRepository({
    required this.store,
  });

  String keyFor(String userId) => 'orders.$userId';

  Future<List<OrderItem>> hydrate(String userId) async {
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

      final orders = <OrderItem>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final o = OrderItem.fromJson(item);
          if (o != null) orders.add(o);
        }
      }
      return orders;
    } catch (_) {
      return [];
    }
  }

  void schedulePersist(String userId, List<OrderItem> orders) {
    final key = keyFor(userId);
    store.write(
      key,
      jsonEncode({
        'orders': orders.take(20).map((o) => o.toJson()).toList(),
      }),
    );
  }

  Future<void> wipeUser(String userId) async {
    await store.remove(keyFor(userId));
  }
}
