import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacustomer_app/core/models/cart_item.dart';
import 'package:pharmacustomer_app/core/providers/cart_notifier.dart';
import 'package:pharmacustomer_app/core/storage/shared_preferences_store.dart';
import 'package:pharmacustomer_app/features/cart/repositories/cart_repository.dart';

void main() {
  group('CartNotifier & CartRepository persistence round-trip', () {
    late InMemoryKeyValueStore store;
    late CartRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = CartRepository(store: store);
    });

    test('add items and restore on fresh CartNotifier instance', () async {
      final cart = CartNotifier(repository);
      cart.bindUser('u_123');

      final item1 = CartItem(
        id: 'p_glycomet_gp2f',
        name: 'Glycomet-GP 2 Forte',
        pack: 'Strip of 15 tablets',
        price: 148.60,
        quantity: 5,
        requiresPrescription: true,
      );
      final item2 = CartItem(
        id: 'p_forxiga_10mg',
        name: 'Forxiga 10mg',
        pack: 'Strip of 10 tablets',
        price: 572.00,
        quantity: 3,
        requiresPrescription: true,
      );

      cart.add(item1);
      cart.add(item2);

      expect(cart.totalCount, 8);
      expect(cart.totalPrice, 2459.0);

      // Verify cold restart on fresh provider
      final hydratedSnapshot = await repository.hydrate('u_123');
      final restoredCart = CartNotifier(repository, hydratedSnapshot);

      expect(restoredCart.totalCount, 8);
      expect(restoredCart.items.length, 2);
      expect(restoredCart.items[0].id, 'p_glycomet_gp2f');
      expect(restoredCart.items[0].quantity, 5);
      expect(restoredCart.items[1].id, 'p_forxiga_10mg');
      expect(restoredCart.items[1].quantity, 3);
      expect(restoredCart.totalPrice, 2459.0);
    });

    test('corrupt blob falls back safely to empty cart without crashing', () async {
      await store.write('cart.u_123', '{ corrupt json ');
      final snapshot = await repository.hydrate('u_123');
      expect(snapshot.lines, isEmpty);
    });

    test('merge guest cart into user cart on login', () async {
      final guestItem = CartItem(
        id: 'p_vit_c',
        name: 'Vitamin C 500mg',
        pack: 'Bottle of 60 tablets',
        price: 120.0,
        quantity: 2,
      );
      final guestCart = CartNotifier(repository);
      guestCart.add(guestItem);

      final merged = await repository.mergeGuestCart('u_123');
      expect(merged.lines.length, 1);
      expect(merged.lines[0].id, 'p_vit_c');
      expect(merged.lines[0].quantity, 2);

      // Guest key must be removed
      final guestRaw = await store.read(CartRepository.guestKey);
      expect(guestRaw, isNull);
    });

    test('wipeUser clears user cart storage', () async {
      final cart = CartNotifier(repository);
      cart.bindUser('u_123');
      cart.add(CartItem(
        id: 'p_1',
        name: 'Item 1',
        pack: 'Pack',
        price: 100,
      ));

      await repository.wipeUser('u_123');
      final raw = await store.read('cart.u_123');
      expect(raw, isNull);
    });
  });
}
