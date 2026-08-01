import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/sync/domain/sync_conflict.dart';

NoteItem _task({
  required String id,
  required String title,
  required DateTime updatedAt,
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

  test('shouldCreateSyncConflict is false when remote is older than local', () {
    final synced = _task(id: 'a', title: 'V1', updatedAt: base);
    final local = _task(id: 'a', title: 'Edit local', updatedAt: base.add(const Duration(hours: 2)));
    final remote = _task(id: 'a', title: 'Remoto viejo', updatedAt: base.add(const Duration(hours: 1)));

    expect(
      shouldCreateSyncConflict(
        local: local,
        syncedSnapshot: synced.toMap(),
        remote: remote,
        entityUpdatedDuringPull: false,
      ),
      isFalse,
    );
  });

  test('buildSyncConflictCopy prefixes title and assigns new id', () {
    final local = _task(id: 'a', title: 'Mi tarea', updatedAt: base);
    final copy = buildSyncConflictCopy(
      local,
      id: 'copy-id',
      now: base.add(const Duration(days: 1)),
    );

    expect(copy.id, 'copy-id');
    expect(copy.title, 'Conflicto de sincronización · Mi tarea');
    expect(copy.updatedAt, base.add(const Duration(days: 1)));
  });
}
