import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

abstract interface class AuthSessionStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _HiveAuthSessionStore implements AuthSessionStore {
  const _HiveAuthSessionStore(this.box);

  final Box<dynamic> box;

  @override
  Future<String?> read(String key) async {
    final value = box.get(key);
    return value is String ? value : null;
  }

  @override
  Future<void> write(String key, String value) => box.put(key, value);

  @override
  Future<void> delete(String key) => box.delete(key);
}

class AuthSessionRepository extends ChangeNotifier {
  AuthSessionRepository._();

  @visibleForTesting
  AuthSessionRepository.forTesting();

  static final instance = AuthSessionRepository._();
  static const _legacyBoxName = 'auth_session';
  static const _accessTokenKey = 'wodo.auth.access_token.v1';
  static const _refreshTokenKey = 'wodo.auth.refresh_token.v1';
  static const _expiresAtKey = 'wodo.auth.expires_at.v1';
  static const _emailKey = 'wodo.auth.email.v1';

  // Keys used by releases that stored the session in Hive.
  static const _legacyAccessTokenKey = 'access_token';
  static const _legacyRefreshTokenKey = 'refresh_token';
  static const _legacyExpiresAtKey = 'expires_at';

  AuthSessionStore? _store;
  AuthSession? _session;
  String? _email;

  AuthSession? get session => _session;
  String? get userEmail => _email;
  bool get isAuthenticated => _session != null;

  Future<void> init() async {
    final legacyBox = await Hive.openBox<dynamic>(_legacyBoxName);
    await initWithStores(
      secureStore: SecureAuthSessionStore(),
      legacyStore: _HiveAuthSessionStore(legacyBox),
    );
  }

  @visibleForTesting
  Future<void> initWithStores({
    required AuthSessionStore secureStore,
    required AuthSessionStore legacyStore,
  }) async {
    _store = secureStore;

    final secureSession = await _readSession(
      secureStore,
      accessTokenKey: _accessTokenKey,
      refreshTokenKey: _refreshTokenKey,
      expiresAtKey: _expiresAtKey,
    );
    if (secureSession != null) {
      _session = secureSession;
      _email = await secureStore.read(_emailKey);
      await _clearLegacy(legacyStore);
      return;
    }

    await _clearSecure(secureStore);
    final legacySession = await _readSession(
      legacyStore,
      accessTokenKey: _legacyAccessTokenKey,
      refreshTokenKey: _legacyRefreshTokenKey,
      expiresAtKey: _legacyExpiresAtKey,
    );
    if (legacySession == null) {
      await _clearLegacy(legacyStore);
      _session = null;
      _email = null;
      return;
    }

    // Delete the Hive values only after all secure writes complete.
    await _writeSession(secureStore, legacySession, email: _email);
    await _clearLegacy(legacyStore);
    _session = legacySession;
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    String? email,
  }) async {
    final store = _requireStore();
    final nextSession = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
    await _writeSession(store, nextSession, email: email);
    _session = nextSession;
    notifyListeners();
  }

  Future<void> clear() async {
    final store = _requireStore();
    _session = null;
    _email = null;
    notifyListeners();
    await _clearSecure(store);
  }

  AuthSessionStore _requireStore() {
    final store = _store;
    if (store == null) {
      throw StateError('AuthSessionRepository is not initialized');
    }
    return store;
  }

  Future<AuthSession?> _readSession(
    AuthSessionStore store, {
    required String accessTokenKey,
    required String refreshTokenKey,
    required String expiresAtKey,
  }) async {
    final values = await Future.wait([
      store.read(accessTokenKey),
      store.read(refreshTokenKey),
      store.read(expiresAtKey),
    ]);
    final accessToken = values[0];
    final refreshToken = values[1];
    final expiresAt = values[2] == null ? null : DateTime.tryParse(values[2]!);
    if (accessToken == null || refreshToken == null || expiresAt == null) {
      return null;
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  Future<void> _writeSession(
    AuthSessionStore store,
    AuthSession session, {
    String? email,
  }) async {
    await store.write(_accessTokenKey, session.accessToken);
    await store.write(_refreshTokenKey, session.refreshToken);
    await store.write(_expiresAtKey, session.expiresAt.toIso8601String());
    final resolvedEmail = email ?? _email;
    if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
      _email = resolvedEmail.trim().toLowerCase();
      await store.write(_emailKey, _email!);
    }
  }

  Future<void> _clearSecure(AuthSessionStore store) async {
    await store.delete(_accessTokenKey);
    await store.delete(_refreshTokenKey);
    await store.delete(_expiresAtKey);
    await store.delete(_emailKey);
  }

  Future<void> _clearLegacy(AuthSessionStore store) async {
    await store.delete(_legacyAccessTokenKey);
    await store.delete(_legacyRefreshTokenKey);
    await store.delete(_legacyExpiresAtKey);
  }
}
