import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/sync/data/sync_service.dart';
import 'package:todos_app/global/widgets/sync_status_banner.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('sync_banner_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<Map>('notes_sync_banner_test');
    await NotesRepository.instance.initWithBox(box);
    await NotesRepository.instance.clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('SyncStatusBanner shows dismissible floating chip while syncing', (
    tester,
  ) async {
    final sync = _FakeSyncService();

    await tester.pumpWidget(
      MaterialApp(
        home: SyncStatusBanner(
          syncService: sync,
          notesRepository: NotesRepository.instance,
          child: const Scaffold(
            body: Center(child: Text('Lista visible')),
          ),
        ),
      ),
    );

    expect(find.text('Lista visible'), findsOneWidget);
    expect(find.text('Actualizando datos…'), findsNothing);

    sync.setState(SyncState.syncing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Actualizando datos…'), findsOneWidget);
    expect(find.text('Lista visible'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    // Floating chip — content below remains visible (not a full-bleed bar).
    final chipTop = tester.getTopLeft(find.text('Actualizando datos…')).dy;
    expect(chipTop, greaterThan(0));

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Actualizando datos…'), findsNothing);
    expect(find.text('Lista visible'), findsOneWidget);

    // Stays dismissed for the same sync session.
    sync.setState(SyncState.syncing);
    await tester.pump();
    expect(find.text('Actualizando datos…'), findsNothing);

    // Reappears on a later sync after idle.
    sync.setState(SyncState.idle);
    await tester.pump();
    sync.setState(SyncState.syncing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Actualizando datos…'), findsOneWidget);

    sync.setState(SyncState.idle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Actualizando datos…'), findsNothing);
    expect(find.text('Lista visible'), findsOneWidget);
  });
}

class _FakeSyncService extends ChangeNotifier implements SyncService {
  SyncState _state = SyncState.idle;

  @override
  SyncState get state => _state;

  void setState(SyncState next) {
    _state = next;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
