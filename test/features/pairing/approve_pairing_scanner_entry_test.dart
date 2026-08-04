import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/pairing/presentation/approve_pairing_screen.dart';
import 'package:todos_app/features/pairing/presentation/scan_pairing_screen.dart';

void main() {
  testWidgets('approve screen shows scan CTA on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(home: ApprovePairingScreen()),
      );
      await tester.pump();

      expect(pairingCameraScannerSupported(), isTrue);
      expect(find.text('Escanear código QR'), findsOneWidget);
      expect(find.text('Introducir código a mano'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('approve screen uses manual entry when scanner unsupported', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        const MaterialApp(home: ApprovePairingScreen()),
      );
      await tester.pump();

      expect(pairingCameraScannerSupported(), isFalse);
      expect(find.text('Escanear código QR'), findsNothing);
      expect(find.text('Confirmar vinculación'), findsOneWidget);
      expect(find.text('Código de vinculación'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
