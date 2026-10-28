import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/storage/user_data_registry.dart';
import '../models/auth_session.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  sessionExpired,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  final UserDataRegistry userDataRegistry;

  AuthStatus _status = AuthStatus.unknown;
  AuthSession? _session;
  bool _disposed = false;

  AuthProvider(
    this._repo, {
    required this.userDataRegistry,
    AuthSession? initial,
    AuthStatus initialStatus = AuthStatus.unknown,
  })  : _session = initial,
        _status = initial != null ? AuthStatus.authenticated : initialStatus;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  String? get userId => _session?.userId;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> restore() async {
    final res = await _repo.restoreSession();
    switch (res.status) {
      case RestoreResultStatus.authenticated:
        _session = res.session;
        _status = AuthStatus.authenticated;
        break;
      case RestoreResultStatus.sessionExpired:
        _session = null;
        _status = AuthStatus.sessionExpired;
        break;
      case RestoreResultStatus.unauthenticated:
        _session = null;
        _status = AuthStatus.unauthenticated;
        break;
    }
    _safeNotify();
  }

  Future<void> onOtpSuccess(AuthSession newSession) async {
    final oldUserId = _session?.userId;
    if (oldUserId != null && oldUserId != newSession.userId) {
      // Different user logging in -> wipe previous user data
      await userDataRegistry.wipeUser(oldUserId);
    }
    ApiService.setToken(newSession.accessToken);
    if (newSession.userId.isNotEmpty && newSession.userId != 'u_customer') {
      ApiService.setCustomerId(newSession.userId);
    }
    await _repo.saveSession(newSession);
    _session = newSession;
    _status = AuthStatus.authenticated;
    _safeNotify();
  }

  Future<void> logout() async {
    final uid = _session?.userId;
    ApiService.setToken(null);
    ApiService.setCustomerId(null);
    if (uid != null) {
      await userDataRegistry.wipeUser(uid);
    }
    await _repo.clearSession();
    _session = null;
    _status = AuthStatus.unauthenticated;
    _safeNotify();
  }

  /// Passive session expiry
  void onSessionExpired() {
    _session = null;
    _status = AuthStatus.sessionExpired;
    _safeNotify();
  }
}
