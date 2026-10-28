import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacustomer_app/core/models/cart_item.dart';
import 'package:pharmacustomer_app/core/providers/cart_notifier.dart';
import 'package:pharmacustomer_app/core/storage/envelope.dart';
import 'package:pharmacustomer_app/core/storage/migrator.dart';
import 'package:pharmacustomer_app/core/storage/shared_preferences_store.dart';
import 'package:pharmacustomer_app/core/storage/user_data_registry.dart';
import 'package:pharmacustomer_app/core/storage/write_coordinator.dart';
import 'package:pharmacustomer_app/core/utils/money.dart';
import 'package:pharmacustomer_app/features/cart/repositories/cart_repository.dart';

void main() {
  group('Money value object', () {
    test('converts rupees to paise accurately without precision loss', () {
      final m = Money.fromRupees(148.60);
      expect(m.paise, 14860);
      expect(m.inRupees, 148.60);
      expect(m.format(), '₹148.60');
    });

    test('calculates bill summary sums correctly', () {
      final item1 = Money.fromRupees(743);
      final item2 = Money.fromRupees(1716);
      final grandTotal = item1 + item2;
      expect(grandTotal.paise, 245900);
      expect(grandTotal.format(), '₹2459');
    });
  });

  group('Envelope & Migrator', () {
    test('encodes and decodes envelope correctly', () {
      final envelope = Envelope(
        v: 1,
        savedAt: DateTime.utc(2026, 10, 15, 7, 32, 10),
        userId: 'u_123',
        data: {'foo': 'bar'},
      );
      final encoded = envelope.encode();
      final decoded = Envelope.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.v, 1);
      expect(decoded.userId, 'u_123');
      expect(decoded.data['foo'], 'bar');
    });

    test('migrator upgrades version from v1 to v2', () {
      final migrator = Migrator();
      migrator.registerMigration(1, (oldData) {
        return {...oldData, 'migrated': true};
      });

      final envelope = Envelope(
        v: 1,
        savedAt: DateTime.utc(2026, 10, 15),
        userId: 'u_123',
        data: {'initial': 1},
      );

      final migrated = migrator.migrate(envelope, 2);
      expect(migrated, isNotNull);
      expect(migrated!.v, 2);
      expect(migrated.data['migrated'], true);
    });
  });

  group('WriteCoordinator', () {
    test('debounces multiple rapid writes and triggers latest', () {
      fakeAsync((async) {
        int writeCount = 0;
        int lastValue = 0;
        final coordinator = WriteCoordinator(key: 'test.key');

        coordinator.schedule(() async {
          writeCount++;
          lastValue = 1;
        });

        async.elapse(const Duration(milliseconds: 100));

        coordinator.schedule(() async {
          writeCount++;
          lastValue = 2;
        });

        async.elapse(const Duration(milliseconds: 260));

        expect(writeCount, 1);
        expect(lastValue, 2);
      });
    });

    test('cancelAndDrop discards pending and advances generation', () {
      fakeAsync((async) {
        bool executed = false;
        final coordinator = WriteCoordinator(key: 'test.key');

        coordinator.schedule(() async {
          executed = true;
        });

        coordinator.cancelAndDrop();
        async.elapse(const Duration(milliseconds: 1500));

        expect(executed, isFalse);
      });
    });
  });

  group('CartNotifier & CartRepository persistence round-trip', () {
    late InMemoryKeyValueStore store;
    late UserDataRegistry registry;
    late Migrator migrator;
    late CartRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      registry = UserDataRegistry();
      migrator = Migrator();
      repository = CartRepository(
        store: store,
        migrator: migrator,
        userDataRegistry: registry,
      );
    });

    test('add items, flush, and restore on fresh CartNotifier instance', () async {
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

      // Flush to disk
      await registry.flushAll();

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
      await registry.flushAll();

      final merged = await repository.mergeGuestCart('u_123');
      expect(merged.lines.length, 1);
      expect(merged.lines[0].id, 'p_vit_c');
      expect(merged.lines[0].quantity, 2);

      // Guest key must be removed
      final guestRaw = await store.read(CartRepository.guestKey);
      expect(guestRaw, isNull);
    });

    test('wipeUser clears user cart storage and cancels pending writes', () async {
      final cart = CartNotifier(repository);
      cart.bindUser('u_123');
      cart.add(CartItem(
        id: 'p_1',
        name: 'Item 1',
        pack: 'Pack',
        price: 100,
      ));
      await registry.flushAll();

      await registry.wipeUser('u_123');
      final raw = await store.read('cart.u_123');
      expect(raw, isNull);
    });
  });
}
