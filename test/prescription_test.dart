import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacustomer_app/core/providers/load_status.dart';
import 'package:pharmacustomer_app/core/storage/envelope.dart';
import 'package:pharmacustomer_app/core/storage/shared_preferences_store.dart';
import 'package:pharmacustomer_app/core/storage/user_data_registry.dart';
import 'package:pharmacustomer_app/features/prescriptions/providers/prescription_provider.dart';
import 'package:pharmacustomer_app/features/prescriptions/repositories/prescription_repository.dart';

void main() {
  group('PrescriptionRepository & Provider lifecycle & security', () {
    late InMemoryKeyValueStore store;
    late UserDataRegistry registry;
    late PrescriptionRepository repo;
    late PrescriptionProvider provider;

    final testRx = Prescription(
      id: 'rx_101',
      source: 'upload',
      status: PrescriptionStatus.uploaded,
      fileName: 'test_prescription.jpg',
      mime: 'image/jpeg',
      sizeBytes: 204800,
      remoteUrl: 'https://cdn.example.com/rx/101.jpg',
      doctorName: 'Dr. Sharma',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

    setUp(() {
      store = InMemoryKeyValueStore();
      registry = UserDataRegistry();
      repo = PrescriptionRepository(
        store: store,
        userDataRegistry: registry,
      );
      provider = PrescriptionProvider(repo);
    });

    test('Prescription JSON serialization roundtrip with all fields', () {
      final json = testRx.toJson();
      final decoded = Prescription.fromJson(json);

      expect(decoded, isNotNull);
      expect(decoded!.id, 'rx_101');
      expect(decoded.fileName, 'test_prescription.jpg');
      expect(decoded.status, PrescriptionStatus.uploaded);
      expect(decoded.doctorName, 'Dr. Sharma');
      expect(decoded.sizeBytes, 204800);
    });

    test('Prescription.fromJson handles invalid / missing fields safely', () {
      expect(Prescription.fromJson({}), isNull);
      expect(Prescription.fromJson({'id': 123}), isNull);
      expect(
        Prescription.fromJson({
          'id': 'rx_bad',
          'source': 'upload',
          'status': 'invalidStatusName', // falls back gracefully
          'fileName': 'doc.pdf',
          'mime': 'application/pdf',
          'sizeBytes': 100,
          'createdAt': 'invalid-date',
          'updatedAt': 'invalid-date',
        }),
        isNotNull,
      );
    });

    test('schedulePersist writes envelope and hydrate restores items', () async {
      repo.schedulePersist('user_test_1', [testRx]);

      // Give debounce a moment to flush
      await Future.delayed(const Duration(milliseconds: 350));

      final raw = await store.read(repo.keyFor('user_test_1'));
      expect(raw, isNotNull);

      final envelope = Envelope.decode(raw!);
      expect(envelope, isNotNull);
      expect(envelope!.userId, 'user_test_1');
      expect(envelope.v, PrescriptionRepository.currentVersion);

      final hydrated = await repo.hydrate('user_test_1');
      expect(hydrated.length, 1);
      expect(hydrated.first.id, 'rx_101');
      expect(hydrated.first.doctorName, 'Dr. Sharma');
    });

    test('hydrate returns empty list if userId does not match (data leak defense)', () async {
      final forgedEnvelope = Envelope(
        v: 1,
        savedAt: DateTime.now().toUtc(),
        userId: 'attacker_user_999',
        data: {
          'prescriptions': [testRx.toJson()]
        },
      );
      await store.write(repo.keyFor('victim_user_1'), forgedEnvelope.encode());

      final results = await repo.hydrate('victim_user_1');
      expect(results, isEmpty);
    });

    test('wipeUser clears stored prescription records for the given user', () async {
      repo.schedulePersist('user_to_wipe', [testRx]);
      await Future.delayed(const Duration(milliseconds: 350));

      expect(await store.read(repo.keyFor('user_to_wipe')), isNotNull);

      await repo.wipeUser('user_to_wipe');
      expect(await store.read(repo.keyFor('user_to_wipe')), isNull);
    });

    test('PrescriptionProvider user binding and status transition', () async {
      provider.bindUser('user_a');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.status, LoadStatus.ready);
      expect(provider.prescriptions, isEmpty);
      expect(provider.latestStatus, PrescriptionStatus.noneAttached);

      provider.addPrescription(testRx);
      expect(provider.prescriptions.length, 1);
      expect(provider.latestStatus, PrescriptionStatus.uploaded);

      provider.reset();
      expect(provider.prescriptions, isEmpty);
    });
  });
}
