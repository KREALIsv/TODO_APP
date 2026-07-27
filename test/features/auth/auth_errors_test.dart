import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/auth/domain/auth_errors.dart';

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

  test('maps email quota exceeded', () {
    expect(
      AuthErrors.message(
        StateError(
          'Has alcanzado el límite de correos para este proceso. Inténtalo más tarde.',
        ),
        registering: false,
      ),
      'Has alcanzado el límite de correos para este proceso. Inténtalo más tarde.',
    );
  });

  test('maps invalid reset token', () {
    expect(
      AuthErrors.message(
        StateError('Invalid or expired reset token'),
        registering: false,
      ),
      contains('caducado'),
    );
  });
}
