import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/sync/domain/sync_conflict.dart';

NoteItem _task({
  required String id,
  required String title,
  required DateTime updatedAt,
  String? syncConflictOfNoteId,
}) {
  return NoteItem(
    id: id,
    type: NoteType.task,
    title: title,
    body: '',
    pinned: false,
    completed: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    syncConflictOfNoteId: syncConflictOfNoteId,
  );
}

void main() {
  final base = DateTime(2026, 7, 31, 12);

  test('shouldCreateSyncConflict is false when local matches sync snapshot', () {
    final local = _task(id: 'a', title: 'Hola', updatedAt: base);
    expect(
      shouldCreateSyncConflict(
        local: local,
        syncedSnapshot: local.toMap(),
        remote: local.copyWith(
          title: 'Remoto',
          updatedAt: base.add(const Duration(hours: 1)),
        ),
        entityUpdatedDuringPull: false,
      ),
      isFalse,
    );
  });

  test('shouldCreateSyncConflict is false during replay of same entity', () {
    final synced = _task(id: 'a', title: 'V1', updatedAt: base);
    final local = _task(id: 'a', title: 'V2', updatedAt: base.add(const Duration(minutes: 5)));
    final remote = _task(id: 'a', title: 'V3', updatedAt: base.add(const Duration(hours: 1)));

    expect(
      shouldCreateSyncConflict(
        local: local,
        syncedSnapshot: synced.toMap(),
        remote: remote,
        entityUpdatedDuringPull: true,
      ),
      isFalse,
    );
  });

  test('shouldCreateSyncConflict is true for genuine concurrent edit', () {
    final synced = _task(id: 'a', title: 'V1', updatedAt: base);
    final local = _task(id: 'a', title: 'Edit local', updatedAt: base.add(const Duration(minutes: 10)));
    final remote = _task(id: 'a', title: 'Remoto', updatedAt: base.add(const Duration(hours: 1)));

    expect(
      shouldCreateSyncConflict(
        local: local,
        syncedSnapshot: synced.toMap(),
        remote: remote,
        entityUpdatedDuringPull: false,
      ),
      isTrue,
    );
  });

  test('isSyncConflictCopy detects metadata and legacy title prefix', () {
    expect(
      isSyncConflictCopy(_task(id: 'a', title: 'Normal', updatedAt: base)),
      isFalse,
    );
    expect(
      isSyncConflictCopy(
        _task(
          id: 'b',
          title: 'Copia',
          updatedAt: base,
          syncConflictOfNoteId: 'canonical',
        ),
      ),
      isTrue,
    );
    expect(
      isSyncConflictCopy(
        _task(
          id: 'c',
          title: 'Conflicto de sincronización · Vieja',
          updatedAt: base,
        ),
      ),
      isTrue,
    );
  });

  test('buildSyncConflictCopy links to canonical note without title prefix', () {
    final local = _task(id: 'a', title: 'Mi tarea', updatedAt: base);
    final copy = buildSyncConflictCopy(
      local,
      id: 'copy-id',
      originalNoteId: 'a',
      now: base.add(const Duration(days: 1)),
    );

    expect(copy.id, 'copy-id');
    expect(copy.title, 'Mi tarea');
    expect(copy.syncConflictOfNoteId, 'a');
    expect(copy.updatedAt, base.add(const Duration(days: 1)));
  });

  test('mergeConflictLocalOntoCanonical applies local fields', () {
    final canonical = _task(id: 'a', title: 'Nube', updatedAt: base);
    final local = _task(
      id: 'copy',
      title: 'Conflicto de sincronización · Local',
      updatedAt: base.add(const Duration(hours: 1)),
      syncConflictOfNoteId: 'a',
    ).copyWith(body: 'detalle local', completed: true);

    final merged = mergeConflictLocalOntoCanonical(
      canonical: canonical,
      localSnapshot: local,
      now: base.add(const Duration(days: 1)),
    );

    expect(merged.id, 'a');
    expect(merged.title, 'Local');
    expect(merged.body, 'detalle local');
    expect(merged.completed, isTrue);
    expect(merged.syncConflictOfNoteId, isNull);
  });
}
