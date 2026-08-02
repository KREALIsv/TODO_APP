import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/sync/domain/sync_conflict.dart';
import 'package:todos_app/features/sync/presentation/sync_conflict_list_card.dart';

void main() {
  testWidgets('SyncConflictListCard shows resolve button', (tester) async {
    final pair = SyncConflictPair(
      copy: NoteItem(
        id: 'copy',
        type: NoteType.task,
        title: 'Mi tarea local',
        body: 'detalle',
        pinned: false,
        completed: false,
        createdAt: DateTime(2026, 7, 31),
        updatedAt: DateTime(2026, 7, 31),
        syncConflictOfNoteId: 'real',
      ),
      canonical: NoteItem(
        id: 'real',
        type: NoteType.task,
        title: 'Versión nube',
        body: '',
        pinned: false,
        completed: false,
        createdAt: DateTime(2026, 7, 31),
        updatedAt: DateTime(2026, 7, 31),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncConflictListCard(pair: pair),
        ),
      ),
    );

    expect(find.text('Mi tarea local'), findsOneWidget);
    expect(find.text('Conflicto de sincronización'), findsOneWidget);
    expect(find.text('En la nube: Versión nube'), findsOneWidget);
    expect(find.text('Resolver'), findsOneWidget);
  });
}
