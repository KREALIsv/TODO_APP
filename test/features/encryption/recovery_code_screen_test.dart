import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/encryption/presentation/recovery_code_screen.dart';

void main() {
  testWidgets('recovery screen offers copy and .txt download', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RecoveryCodeScreen(
          recoveryCode: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('ABCD-EFGH'), findsOneWidget);
    expect(find.text('Copiar código'), findsOneWidget);
    expect(find.text('Descargar .txt'), findsOneWidget);
    expect(find.text('Lo guardé en un lugar seguro'), findsOneWidget);
  });
}
