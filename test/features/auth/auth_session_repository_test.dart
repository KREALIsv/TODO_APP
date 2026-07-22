import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/auth/data/auth_session_repository.dart';

void main() {
  late AuthSessionRepository repository;
  late _MemorySessionStore secure;
  late _MemorySessionStore legacy;

  setUp(() {
    repository = AuthSessionRepository.forTesting();
    secure = _MemorySessionStore();
    legacy = _MemorySessionStore();
  });

  test('migrates a complete legacy Hive session to secure storage', () async {
    legacy.values.addAll({
      'access_token': 'legacy-access',
      'refresh_token': 'legacy-refresh',
      'expires_at': DateTime(2030).toIso8601String(),
    });

    await repository.initWithStores(secureStore: secure, legacyStore: legacy);

    expect(repository.session?.accessToken, 'legacy-access');
    expect(secure.values['wodo.auth.access_token.v1'], 'legacy-access');
    expect(secure.values['wodo.auth.refresh_token.v1'], 'legacy-refresh');
    expect(legacy.values, isEmpty);
  });

  test('prefers an existing secure session and erases legacy tokens', () async {
    secure.values.addAll({
      'wodo.auth.access_token.v1': 'secure-access',
      'wodo.auth.refresh_token.v1': 'secure-refresh',
      'wodo.auth.expires_at.v1': DateTime(2030).toIso8601String(),
    });
    legacy.values.addAll({
      'access_token': 'old-access',
      'refresh_token': 'old-refresh',
      'expires_at': DateTime(2030).toIso8601String(),
    });

    await repository.initWithStores(secureStore: secure, legacyStore: legacy);

    expect(repository.session?.accessToken, 'secure-access');
    expect(legacy.values, isEmpty);
  });

  test('save and clear never write tokens to the legacy store', () async {
    await repository.initWithStores(secureStore: secure, legacyStore: legacy);

    await repository.save(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      expiresInSeconds: 900,
      email: 'maria@example.com',
    );

    expect(repository.isAuthenticated, isTrue);
    expect(repository.userEmail, 'maria@example.com');
    expect(secure.values['wodo.auth.access_token.v1'], 'new-access');
    expect(secure.values['wodo.auth.email.v1'], 'maria@example.com');
    expect(legacy.values, isEmpty);

    await repository.rememberLoginEmail('other@example.com');
    expect(repository.lastLoginEmail, 'other@example.com');
    expect(secure.values['wodo.auth.last_login_email.v1'], 'other@example.com');

    await repository.clearRememberedLoginEmail();
    expect(repository.lastLoginEmail, isNull);

    await repository.clear();
    expect(repository.isAuthenticated, isFalse);
    expect(repository.userEmail, isNull);
    expect(secure.values, isEmpty);
  });

  test('rejects and removes incomplete legacy credentials', () async {
    legacy.values['access_token'] = 'orphan-token';

    await repository.initWithStores(secureStore: secure, legacyStore: legacy);

    expect(repository.isAuthenticated, isFalse);
    expect(legacy.values, isEmpty);
    expect(secure.values, isEmpty);
  });
}

class _MemorySessionStore implements AuthSessionStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
