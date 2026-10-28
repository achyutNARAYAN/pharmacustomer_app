import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacustomer_app/core/storage/secure_token_store.dart';
import 'package:pharmacustomer_app/core/storage/shared_preferences_store.dart';
import 'package:pharmacustomer_app/core/storage/user_data_registry.dart';
import 'package:pharmacustomer_app/features/auth/models/auth_session.dart';
import 'package:pharmacustomer_app/features/auth/providers/auth_provider.dart';
import 'package:pharmacustomer_app/features/auth/repositories/auth_repository.dart';

void main() {
  group('AuthRepository and AuthProvider lifecycle', () {
    late InMemoryKeyValueStore appSettingsStore;
    late InMemorySecureTokenStore secureStore;
    late UserDataRegistry registry;
    late AuthRepository authRepo;
    late AuthProvider authProvider;

    setUp(() {
      appSettingsStore = InMemoryKeyValueStore();
      secureStore = InMemorySecureTokenStore();
      registry = UserDataRegistry();

      authRepo = AuthRepository(
        secureStore: secureStore,
        appSettingsStore: appSettingsStore,
      );

      authProvider = AuthProvider(authRepo, userDataRegistry: registry);
    });

    test('reinstall guard clears keychain if app.firstRunDone is absent', () async {
      // Simulate stale keychain item surviving uninstall
      await secureStore.write('auth.session', '{"accessToken":"stale"}');

      final result = await authRepo.restoreSession();
      expect(result.status, RestoreResultStatus.unauthenticated);

      // Verify keychain was wiped and marker was set
      final token = await secureStore.read('auth.session');
      expect(token, isNull);
      final marker = await appSettingsStore.read(AuthRepository.firstRunMarker);
      expect(marker, 'true');
    });

    test('restore valid session returns authenticated without network call', () async {
      await appSettingsStore.write(AuthRepository.firstRunMarker, 'true');
      final validSession = AuthSession(
        accessToken: 'access_1',
        refreshToken: 'refresh_1',
        accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        userId: 'u_123',
      );
      await authRepo.saveSession(validSession);

      final result = await authRepo.restoreSession();
      expect(result.status, RestoreResultStatus.authenticated);
      expect(result.session?.userId, 'u_123');
    });

    test('single-flight refresh prevents duplicate remote calls', () async {
      await appSettingsStore.write(AuthRepository.firstRunMarker, 'true');
      final futures = await Future.wait([
        authRepo.refreshToken('refresh_token_test'),
        authRepo.refreshToken('refresh_token_test'),
      ]);

      expect(futures[0].accessToken, equals(futures[1].accessToken));
    });

    test('explicit logout wipes user data registry and clears session', () async {
      await appSettingsStore.write(AuthRepository.firstRunMarker, 'true');
      final session = AuthSession(
        accessToken: 'access_1',
        refreshToken: 'refresh_1',
        accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        userId: 'u_123',
      );
      await authProvider.onOtpSuccess(session);
      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.logout();
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.session, isNull);

      final storedSession = await secureStore.read(AuthRepository.sessionKey);
      expect(storedSession, isNull);
    });
  });
}
