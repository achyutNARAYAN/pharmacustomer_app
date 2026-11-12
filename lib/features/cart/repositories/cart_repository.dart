import 'package:flutter/foundation.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/envelope.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/migrator.dart';
import '../../../core/storage/user_data_registry.dart';
import '../../../core/storage/write_coordinator.dart';
import '../models/cart_merge_policy.dart';
import '../models/cart_snapshot.dart';

import '../../../core/services/api_service.dart';
import '../models/cart_models.dart';

class CartRepository implements UserScopedStore {
  static const int currentVersion = 1;
  static const String guestKey = 'cart.guest';

  final KeyValueStore store;
  final Migrator migrator;
  final UserDataRegistry userDataRegistry;
  final AppLogger? logger;

  final Map<String, WriteCoordinator> _coordinators = {};

  CartRepository({
    required this.store,
    required this.migrator,
    required this.userDataRegistry,
    this.logger,
  }) {
    userDataRegistry.registerStore(this);
  }

  // ── Remote API Integration (Module 5: 11 Endpoints) ───────────────────────

  /// 1. Syncs active remote cart with live catalogue pricing and summary flags
  Future<GetCartResponse?> fetchRemoteCartEnvelope() async {
    try {
      final res = await ApiService.getCart();
      if (res != null) {
        return GetCartResponse.fromJson(res);
      }
    } catch (e) {
      logger?.warning('Failed to fetch remote cart envelope: $e');
    }
    return null;
  }

  /// Backward compatible helper returning CartSnapshot for local hydration
  Future<CartSnapshot?> fetchRemoteCart() async {
    try {
      final envelope = await fetchRemoteCartEnvelope();
      if (envelope != null) {
        final lines = envelope.cart.items.map((i) => i.toCartItem()).toList();
        final rxList = envelope.cart.prescriptionId != null ? [envelope.cart.prescriptionId!] : <String>[];
        return CartSnapshot(
          lines: lines,
          prescriptionIds: rxList,
          lastSyncedAt: envelope.cart.updatedAt ?? DateTime.now(),
        );
      }
    } catch (e) {
      logger?.warning('Failed to fetch remote cart: $e');
    }
    return null;
  }

  /// 2. Add medicine to active cart via API
  Future<CartModel?> addRemoteItem(String medicineId, [int quantity = 1]) async {
    try {
      final res = await ApiService.addCartItem(medicineId, quantity);
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.addRemoteItem failed: $e');
      rethrow;
    }
    return null;
  }

  /// 3. Update quantity of existing cart line item by its line item _id
  Future<CartModel?> updateRemoteQuantity(String lineItemId, int quantity) async {
    try {
      final res = await ApiService.updateCartItemQuantity(lineItemId, quantity);
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.updateRemoteQuantity failed: $e');
      rethrow;
    }
    return null;
  }

  /// 4. Remove a line item from cart by its line item _id
  Future<CartModel?> removeRemoteItem(String lineItemId) async {
    try {
      final res = await ApiService.removeCartItem(lineItemId);
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.removeRemoteItem failed: $e');
      rethrow;
    }
    return null;
  }

  /// 5. Clear entire cart
  Future<CartModel?> clearRemoteCart() async {
    try {
      final res = await ApiService.clearCart();
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.clearRemoteCart failed: $e');
      rethrow;
    }
    return null;
  }

  /// 6. Preview 4km blind store allocation with FEFO check
  Future<Map<String, dynamic>?> allocateStoreRemote(String addressId) async {
    try {
      return await ApiService.allocateStore(addressId);
    } catch (e) {
      logger?.error('CartRepository.allocateStoreRemote failed: $e');
      rethrow;
    }
  }

  /// 7. Attach verified (APPROVED) prescription to cart
  Future<CartModel?> attachPrescriptionRemote(String prescriptionId) async {
    try {
      final res = await ApiService.attachCartPrescription(prescriptionId);
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.attachPrescriptionRemote failed: $e');
      rethrow;
    }
    return null;
  }

  /// 8. Remove attached prescription from cart
  Future<CartModel?> removePrescriptionRemote() async {
    try {
      final res = await ApiService.removeCartPrescription();
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.removePrescriptionRemote failed: $e');
      rethrow;
    }
    return null;
  }

  /// 9. Apply promotional coupon (e.g. WELCOME50, SAVE10)
  Future<CartModel?> applyCouponRemote(String couponCode) async {
    try {
      final res = await ApiService.applyCoupon(couponCode);
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.applyCouponRemote failed: $e');
      rethrow;
    }
    return null;
  }

  /// 10. Remove applied coupon
  Future<CartModel?> removeCouponRemote() async {
    try {
      final res = await ApiService.removeCoupon();
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.removeCouponRemote failed: $e');
      rethrow;
    }
    return null;
  }

  /// 11. Atomic checkout orchestration with 15-minute stock hold
  Future<CartModel?> checkoutRemote({
    required String addressId,
    String? prescriptionId,
    String? couponCode,
  }) async {
    try {
      final res = await ApiService.checkout(
        addressId: addressId,
        prescriptionId: prescriptionId,
        couponCode: couponCode,
      );
      if (res is Map<String, dynamic>) {
        return CartModel.fromJson(res);
      }
    } catch (e) {
      logger?.error('CartRepository.checkoutRemote failed: $e');
      rethrow;
    }
    return null;
  }

  /// Syncs an item quantity change to ApiService if online
  Future<void> syncItemToRemote(String medicineId, int quantity) async {
    try {
      await ApiService.addCartItem(medicineId, quantity);
    } catch (e) {
      logger?.warning('Failed to sync item to remote cart: $e');
    }
  }

  String keyFor(String? userId) {
    if (userId == null || userId.isEmpty) return guestKey;
    return 'cart.$userId';
  }

  WriteCoordinator coordinatorFor(String? userId) {
    final key = keyFor(userId);
    return _coordinators.putIfAbsent(key, () {
      final c = WriteCoordinator(key: key, logger: logger);
      userDataRegistry.registerCoordinator(c);
      return c;
    });
  }

  /// Hydrate cart for a user (or guest).
  /// Never throws: invalid blobs are discarded and return empty snapshot.
  Future<CartSnapshot> hydrate(String? userId) async {
    final key = keyFor(userId);
    try {
      final raw = await store.read(key);
      if (raw == null || raw.isEmpty) {
        return CartSnapshot.empty;
      }

      final envelope = Envelope.decode(raw);
      if (envelope == null) {
        await _handleCorruptBlob(key, raw);
        return CartSnapshot.empty;
      }

      // Check userId match: guest cart envelope has null userId, user cart has matching userId
      if (envelope.userId != userId) {
        logger?.warning('Cart envelope userId mismatch: expected $userId, got ${envelope.userId}');
        return CartSnapshot.empty;
      }

      Envelope? currentEnvelope = envelope;
      if (envelope.v != currentVersion) {
        currentEnvelope = migrator.migrate(envelope, currentVersion);
        if (currentEnvelope == null) {
          logger?.warning('Failed to migrate cart from version ${envelope.v}');
          return CartSnapshot.empty;
        }
      }

      final snapshot = CartSnapshot.fromJson(currentEnvelope.data);
      if (snapshot == null) {
        await _handleCorruptBlob(key, raw);
        return CartSnapshot.empty;
      }

      return snapshot;
    } catch (e, st) {
      logger?.error('Error hydrating cart for $key', e, st);
      return CartSnapshot.empty;
    }
  }

  /// Schedule a snapshot save with debouncing and serialization.
  void schedulePersist(String? userId, CartSnapshot snapshot) {
    final coordinator = coordinatorFor(userId);
    coordinator.schedule(() async {
      await _writeDirect(userId, snapshot);
    });
  }

  Future<void> _writeDirect(String? userId, CartSnapshot snapshot) async {
    final key = keyFor(userId);
    final envelope = Envelope(
      v: currentVersion,
      savedAt: DateTime.now().toUtc(),
      userId: userId,
      data: snapshot.toJson(),
    );
    await store.write(key, envelope.encode());
  }

  Future<void> _handleCorruptBlob(String key, String raw) async {
    logger?.error('Corrupt cart data detected at $key');
    if (kDebugMode) {
      await store.write('$key.corrupt', raw);
    }
    await store.remove(key);
  }

  /// Merges guest cart into user cart on login and removes guest key.
  Future<CartSnapshot> mergeGuestCart(String userId) async {
    final guestSnapshot = await hydrate(null);
    final userSnapshot = await hydrate(userId);

    if (guestSnapshot.lines.isEmpty) {
      await store.remove(guestKey);
      return userSnapshot;
    }

    final mergedLines = CartMergePolicy.mergeMaxQuantity(
      guestSnapshot.lines,
      userSnapshot.lines,
    );

    final mergedRx = {...guestSnapshot.prescriptionIds, ...userSnapshot.prescriptionIds}.toList();

    final mergedSnapshot = CartSnapshot(
      lines: mergedLines,
      prescriptionIds: mergedRx,
      revision: userSnapshot.revision,
      lastSyncedAt: userSnapshot.lastSyncedAt,
    );

    await _writeDirect(userId, mergedSnapshot);
    await store.remove(guestKey);
    return mergedSnapshot;
  }

  @override
  Future<void> wipeUser(String userId) async {
    final key = keyFor(userId);
    _coordinators[key]?.cancelAndDrop();
    await store.remove(key);
  }
}
