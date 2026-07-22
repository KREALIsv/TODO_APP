import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/billing/presentation/plus_onboarding_screen.dart';

void main() {
  testWidgets('presents benefits before the commercial offer on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PlusOnboardingScreen()));

    expect(find.text('Tus ideas, protegidas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Tu WODO va contigo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Elige cómo cuidar tus datos'), findsOneWidget);
    expect(find.text(r'$29.99'), findsOneWidget);
    expect(find.text(r'$3.99'), findsOneWidget);
    expect(find.text('Crear cuenta y continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
