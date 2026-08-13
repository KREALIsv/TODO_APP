import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/app_lock/presentation/app_lock_screens.dart';
import 'package:todos_app/features/settings/domain/privacy_security_status.dart';

void main() {
  testWidgets('setup screen rejects mismatched PINs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLockSetupScreen()));

    expect(find.text(PrivacySecurityCopy.appLockTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '1234');
    await tester.enterText(find.byType(TextField).at(1), '4321');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Los PIN no coinciden.'), findsOneWidget);
  });

  testWidgets('setup screen pops the confirmed PIN', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AppLockSetupScreen()),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '2580');
    await tester.enterText(find.byType(TextField).at(1), '2580');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pumpAndSettle();

    expect(result, '2580');
  });
}
