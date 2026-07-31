import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:todos_app/core/theme/theme.dart';
import 'package:todos_app/features/auth/data/auth_session_repository.dart';
import 'package:todos_app/features/profile/presentation/profile_account_section.dart';
import 'package:todos_app/features/profile/presentation/profile_panel.dart';

void main() {
  testWidgets('logged-in sidebar stacks Sincronizar and Salir on one line', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final hiveDir = Directory.systemTemp.createTempSync('wodo_profile_test_');
    Hive.init(hiveDir.path);

    final secure = _MemorySessionStore();
    await AuthSessionRepository.instance.initWithStores(
      secureStore: secure,
      legacyStore: _MemorySessionStore(),
    );
    await AuthSessionRepository.instance.save(
      accessToken: 'demo-access',
      refreshToken: 'demo-refresh',
      expiresInSeconds: 86400,
      email: 'maria@wodo.app',
    );

    await tester.binding.setSurfaceSize(const Size(400, 560));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F0FA),
          body: SizedBox(
            width: 300,
            child: ProfileAccountSection(
              density: ProfilePanelDensity.sidebar,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sincronizar'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
    expect(
      find.textContaining('estará disponible pronto'),
      findsNothing,
    );

    final syncLabel = tester.widget<Text>(find.text('Sincronizar'));
    expect(syncLabel.maxLines, 1);
    expect(syncLabel.softWrap, isFalse);
  });
}

class _MemorySessionStore implements AuthSessionStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
