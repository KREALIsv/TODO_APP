import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/sync/domain/sync_conflict.dart';
import 'package:todos_app/features/sync/domain/sync_snapshot.dart';

Map<String, dynamic> _noteMap({
  required String id,
  String title = 'Tarea',
  String? syncConflictOfNoteId,
}) {
  return {
    'id': id,
    'type': 'task',
    'title': title,
    'body': '',
    'pinned': false,
    'completed': false,
    'createdAt': '2026-07-31T12:00:00.000',
    'updatedAt': '2026-07-31T12:00:00.000',
    'tags': <String>[],
    'dueHasTime': false,
    if (syncConflictOfNoteId != null)
      'syncConflictOfNoteId': syncConflictOfNoteId,
  };
}

SyncMutationPayload _fakeMutation({
  required String entityType,
  required String entityId,
  required String operation,
  Map<String, dynamic>? payload,
}) {
  return {
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation,
    if (payload != null) 'payload': payload,
  };
}

void main() {
  test('isSyncConflictNoteMap detects metadata and legacy title', () {
    expect(isSyncConflictNoteMap(_noteMap(id: 'a')), isFalse);
    expect(
      isSyncConflictNoteMap(
        _noteMap(id: 'b', syncConflictOfNoteId: 'real'),
      ),
      isTrue,
    );
    expect(
      isSyncConflictNoteMap(
        _noteMap(
          id: 'c',
          title: 'Conflicto de sincronización · Vieja',
        ),
      ),
      isTrue,
    );
  });

  test('buildSyncNoteSection excludes conflict copies', () {
    final section = buildSyncNoteSection([
      _noteMap(id: 'real'),
      _noteMap(id: 'copy', syncConflictOfNoteId: 'real'),
    ]);

    expect(section.keys, ['real']);
  });

  test('sanitizeSyncNoteSection strips conflict copies from stored snapshot', () {
    final sanitized = sanitizeSyncNoteSection({
      'real': _noteMap(id: 'real'),
      'copy': _noteMap(id: 'copy', syncConflictOfNoteId: 'real'),
    });

    expect(sanitized.keys, ['real']);
  });

  test('buildSyncPushMutations never creates conflict copy notes', () {
    final current = {
      'note': buildSyncNoteSection([
        _noteMap(id: 'real', title: 'Canonical'),
        _noteMap(id: 'copy', syncConflictOfNoteId: 'real'),
      ]),
    };

    final mutations = buildSyncPushMutations(
      previous: const {},
      current: current,
      mutationBuilder: _fakeMutation,
    );

    expect(mutations.length, 1);
    expect(mutations.single['entityId'], 'real');
    expect(mutations.single['operation'], 'CREATE');
  });

  test(
    'buildSyncPushMutations deletes legacy conflict copies from old snapshots',
    () {
      final previous = {
        'note': {
          'real': _noteMap(id: 'real'),
          'copy': _noteMap(id: 'copy', syncConflictOfNoteId: 'real'),
        },
      };
      final current = {
        'note': buildSyncNoteSection([_noteMap(id: 'real')]),
      };

      final mutations = buildSyncPushMutations(
        previous: sanitizeSyncSnapshot(previous),
        current: current,
        mutationBuilder: _fakeMutation,
      );

      expect(mutations, isEmpty);
    },
  );

  test('shouldIgnoreRemoteNoteMutation blocks pulled conflict payloads', () {
    expect(
      shouldIgnoreRemoteNoteMutation(_noteMap(id: 'real')),
      isFalse,
    );
    expect(
      shouldIgnoreRemoteNoteMutation(
        _noteMap(id: 'copy', syncConflictOfNoteId: 'real'),
      ),
      isTrue,
    );
  });

  test(
    'withConflictCopyCleanupDeletes removes legacy conflict copies from server',
    () {
      final rawPrevious = {
        'note': {
          'real': _noteMap(id: 'real'),
          'copy': _noteMap(id: 'copy', syncConflictOfNoteId: 'real'),
        },
      };
      final current = {
        'note': buildSyncNoteSection([_noteMap(id: 'real')]),
      };

      final mutations = withConflictCopyCleanupDeletes(
        rawPrevious: rawPrevious,
        mutations: buildSyncPushMutations(
          previous: sanitizeSyncSnapshot(rawPrevious),
          current: current,
          mutationBuilder: _fakeMutation,
        ),
        deleteBuilder: ({
          required entityType,
          required entityId,
          required operation,
        }) =>
            _fakeMutation(
          entityType: entityType,
          entityId: entityId,
          operation: operation,
        ),
      );

      expect(
        mutations.where(
          (m) => m['entityId'] == 'copy' && m['operation'] == 'DELETE',
        ),
        hasLength(1),
      );
    },
  );

  test('comment snapshot produces create mutation', () {
    final comment = {
      'id': 'c1',
      'noteId': 'n1',
      'body': 'Hola',
      'createdAt': '2026-08-19T10:00:00.000',
    };
    final mutations = buildSyncPushMutations(
      previous: {
        'note': {},
        'comment': {},
      },
      current: {
        'note': {},
        'comment': {'c1': comment},
      },
      mutationBuilder: _fakeMutation,
    );
    expect(mutations, hasLength(1));
    expect(mutations.single['entityType'], 'comment');
    expect(mutations.single['operation'], 'CREATE');
    expect(mutations.single['payload'], comment);
  });
}
