import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('login screen shows phone QR entry CTA', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.textContaining('Entrar con'), findsOneWidget);
    expect(find.textContaining('Muestra un QR'), findsOneWidget);
  });
}
