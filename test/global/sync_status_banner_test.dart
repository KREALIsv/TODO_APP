import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/sync/data/sync_service.dart';
import 'package:todos_app/global/widgets/sync_status_banner.dart';

void main() {
  testWidgets('SyncStatusBanner shows compact overlay while syncing', (
    tester,
  ) async {
    final sync = _FakeSyncService();

    await tester.pumpWidget(
      MaterialApp(
        home: SyncStatusBanner(
          syncService: sync,
          child: const Scaffold(body: Text('Lista visible')),
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
