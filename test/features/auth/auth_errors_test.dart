import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/auth/domain/auth_errors.dart';
import 'package:todos_app/features/auth/domain/auth_session_expired_exception.dart';

void main() {
  test('maps invalid credentials to Spanish', () {
    expect(
      AuthErrors.message(StateError('Invalid credentials'), registering: false),
      contains('Correo o contraseña incorrectos'),
    );
  });

  test('maps email already registered when registering', () {
    expect(
      AuthErrors.message(
        StateError('Email already registered'),
        registering: true,
      ),
      contains('Usar otra cuenta'),
    );
  });

  test('maps unauthorized API errors to friendly session copy', () {
    expect(
      AuthErrors.fromHttpFailure(
        statusCode: 401,
        apiMessage: 'Unauthorized',
      ),
      contains('sesión en la nube expiró'),
    );
    expect(
      AuthErrors.fromHttpFailure(
        statusCode: 401,
        apiMessage: 'Invalid credentials',
      ),
      contains('Correo o contraseña incorrectos'),
    );
    expect(
      AuthErrors.message(
        AuthSessionExpiredException(AuthErrors.sessionExpiredMessage()),
        registering: false,
      ),
      contains('iniciar sesión'),
    );
  });
}
