import 'dart:convert';
import '../../../core/models/cart_item.dart';
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
  final List<CartItem>? items;

  const OrderItem({
    required this.orderId,
    required this.status,
    required this.totalPaise,
    required this.itemCount,
    required this.createdAt,
    this.items,
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
        if (items != null)
          'items': items!.map((i) => {
            'id': i.id,
            'name': i.name,
            'pack': i.pack,
            'price': i.price,
            'quantity': i.quantity,
            'requiresPrescription': i.requiresPrescription,
          }).toList(),
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

    final rawItems = json['items'];
    List<CartItem>? items;
    if (rawItems is List) {
      items = rawItems.map((itemJson) {
        if (itemJson is Map<String, dynamic>) {
          return CartItem(
            id: itemJson['id']?.toString() ?? '',
            name: itemJson['name']?.toString() ?? 'Medicine',
            pack: itemJson['pack']?.toString() ?? '1 Unit',
            price: (itemJson['price'] as num?)?.toDouble() ?? 0.0,
            quantity: (itemJson['quantity'] as num?)?.toInt() ?? 1,
            requiresPrescription: itemJson['requiresPrescription'] == true,
          );
        }
        return null;
      }).whereType<CartItem>().toList();
    }

    return OrderItem(
      orderId: orderId,
      status: status,
      totalPaise: totalPaise,
      itemCount: itemCount,
      createdAt: createdAt,
      items: items,
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
      bool hadLegacyMock = false;
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final o = OrderItem.fromJson(item);
          if (o != null) {
            // Discard legacy mocked orders generated with local AC- prefix
            if (o.orderId.startsWith('AC-')) {
              hadLegacyMock = true;
            } else {
              orders.add(o);
            }
          }
        }
      }
      if (hadLegacyMock) {
        schedulePersist(userId, orders);
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

  Future<void> clearOrders(String userId) async {
    await store.remove(keyFor(userId));
  }

  Future<void> wipeUser(String userId) async {
    await store.remove(keyFor(userId));
  }
}
