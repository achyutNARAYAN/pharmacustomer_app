import 'dart:async';
import 'dart:convert';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/secure_token_store.dart';
import '../models/auth_session.dart';

import '../../../core/services/api_service.dart';

enum RestoreResultStatus {
  authenticated,
  unauthenticated,
  sessionExpired,
}

class RestoreResult {
  final RestoreResultStatus status;
  final AuthSession? session;

  const RestoreResult(this.status, [this.session]);
}

class AuthRepository {
  static const String sessionKey = 'auth.session';
  static const String firstRunMarker = 'app.firstRunDone';

  final SecureTokenStore secureStore;
  final KeyValueStore appSettingsStore;
  final AppLogger? logger;

  Completer<AuthSession>? _activeRefreshFlight;

  AuthRepository({
    required this.secureStore,
    required this.appSettingsStore,
    this.logger,
  });

  /// Step 1 to 5 of restoreSession()
  Future<RestoreResult> restoreSession() async {
    try {
      // 1. Reinstall guard: check app.firstRunDone in shared prefs (which is wiped on reinstall).
      final firstRunDone = await appSettingsStore.read(firstRunMarker);
      if (firstRunDone == null) {
        logger?.info('First run after install detected: clearing legacy Keychain.');
        await secureStore.deleteAll();
        await appSettingsStore.write(firstRunMarker, 'true');
        return const RestoreResult(RestoreResultStatus.unauthenticated);
      }

      // 2. Read session from SecureTokenStore with retry up to 3 times
      String? rawSession;
      int attempts = 0;
      while (attempts < 3) {
        try {
          rawSession = await secureStore.read(sessionKey);
          break;
        } catch (e) {
          attempts++;
          if (attempts >= 3) {
            logger?.error('SecureTokenStore read failed 3 times', e);
            return const RestoreResult(RestoreResultStatus.unauthenticated);
          }
          await Future<void>.delayed(Duration(milliseconds: 100 * attempts));
        }
      }

      // 3. No session -> unauthenticated
      if (rawSession == null || rawSession.isEmpty) {
        return const RestoreResult(RestoreResultStatus.unauthenticated);
      }

      final json = jsonDecode(rawSession) as Map<String, dynamic>;
      final session = AuthSession.fromJson(json);
      if (session == null) {
        return const RestoreResult(RestoreResultStatus.unauthenticated);
      }

      // 4. Access token still valid (60s skew) -> authenticated
      if (!session.isExpired) {
        ApiService.setToken(session.accessToken);
        if (session.userId.isNotEmpty && session.userId != 'u_customer') {
          ApiService.setCustomerId(session.userId);
        }
        return RestoreResult(RestoreResultStatus.authenticated, session);
      }

      // 5. Expired -> single-flight refresh with 5s timeout
      try {
        final refreshed = await refreshToken(session.refreshToken)
            .timeout(const Duration(seconds: 5));
        return RestoreResult(RestoreResultStatus.authenticated, refreshed);
      } on TimeoutException {
        logger?.warning('Token refresh timed out. Falling back to stale token while offline.');
        return RestoreResult(RestoreResultStatus.authenticated, session);
      } on AuthFailure {
        logger?.warning('Token refresh rejected. Session expired.');
        return const RestoreResult(RestoreResultStatus.sessionExpired);
      } catch (e) {
        logger?.warning('Token refresh failed ($e). Staying authenticated on stale token.');
        return RestoreResult(RestoreResultStatus.authenticated, session);
      }
    } catch (e, st) {
      logger?.error('restoreSession unexpected failure', e, st);
      return const RestoreResult(RestoreResultStatus.unauthenticated);
    }
  }

  /// Single-flight refresh token
  Future<AuthSession> refreshToken(String refreshToken) async {
    if (_activeRefreshFlight != null) {
      return _activeRefreshFlight!.future;
    }

    final completer = Completer<AuthSession>();
    _activeRefreshFlight = completer;

    try {
      final newSession = AuthSession(
        accessToken: refreshToken,
        refreshToken: refreshToken,
        accessExpiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
        userId: 'u_customer',
      );
      ApiService.setToken(newSession.accessToken);
      await saveSession(newSession);
      completer.complete(newSession);
      return newSession;
    } catch (e) {
      completer.completeError(const AuthFailure('Failed to refresh token'));
      rethrow;
    } finally {
      _activeRefreshFlight = null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    ApiService.setToken(session.accessToken);
    final encoded = jsonEncode(session.toJson());
    await secureStore.write(sessionKey, encoded);
  }

  Future<void> clearSession() async {
    ApiService.setToken(null);
    await secureStore.delete(sessionKey);
  }
}
