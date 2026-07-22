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
}
