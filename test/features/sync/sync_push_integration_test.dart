import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/sync/domain/sync_snapshot.dart';

/// Simulates two devices sharing a mutation log through in-memory snapshots.
void main() {
  Map<String, dynamic> note({
    required String id,
    required String title,
    String updatedAt = '2026-07-31T12:00:00.000',
    String? syncConflictOfNoteId,
  }) {
    return {
      'id': id,
      'type': 'task',
      'title': title,
      'body': '',
      'pinned': false,
      'completed': false,
      'createdAt': '2026-07-31T10:00:00.000',
      'updatedAt': updatedAt,
      'tags': <String>[],
      'dueHasTime': false,
      if (syncConflictOfNoteId != null)
        'syncConflictOfNoteId': syncConflictOfNoteId,
    };
  }

  SyncEntitySnapshot deviceSnapshot(List<Map<String, dynamic>> notes) {
    return {
      'note': buildSyncNoteSection(notes),
      'tag': {},
      'dayEntry': {},
    };
  }

  List<SyncMutationPayload> pushMutations({
    required SyncEntitySnapshot previous,
    required SyncEntitySnapshot current,
  }) {
    return buildSyncPushMutations(
      previous: previous,
      current: current,
      mutationBuilder: ({
        required entityType,
        required entityId,
        required operation,
        payload,
      }) =>
          {
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        if (payload != null) 'payload': payload,
      },
    );
  }

  SyncEntitySnapshot applyMutations(
    SyncEntitySnapshot base,
    List<SyncMutationPayload> mutations,
  ) {
    final next = {
      for (final section in base.entries)
        section.key: Map<String, Map<String, dynamic>>.from(section.value),
    };

    for (final mutation in mutations) {
      final entityType = mutation['entityType'] as String;
      final entityId = mutation['entityId'] as String;
      final operation = mutation['operation'] as String;
      final section = next.putIfAbsent(entityType, () => {});
      if (operation == 'DELETE') {
        section.remove(entityId);
        continue;
      }
      if (operation == 'CREATE' || operation == 'UPDATE') {
        final payload = mutation['payload'];
        if (payload is! Map<String, dynamic>) continue;
        if (entityType == 'note' && shouldIgnoreRemoteNoteMutation(payload)) {
          continue;
        }
        section[entityId] = Map<String, dynamic>.from(payload);
      }
    }

    return next;
  }

  test('device A push excludes conflict copy; device B never receives it', () {
    final deviceA = deviceSnapshot([
      note(id: 'task-1', title: 'En la nube'),
      note(
        id: 'conflict-copy',
        title: 'Mi versión',
        syncConflictOfNoteId: 'task-1',
      ),
    ]);

    final pushed = pushMutations(previous: const {}, current: deviceA);
    expect(pushed.map((m) => m['entityId']), ['task-1']);

    final deviceB = applyMutations(const {}, pushed);
    expect(deviceB['note']!.keys, ['task-1']);
    expect(deviceB['note']!['task-1']!['title'], 'En la nube');
  });

  test('two-device edit propagates canonical note only', () {
    final deviceA = deviceSnapshot([
      note(id: 'task-1', title: 'Versión A', updatedAt: '2026-07-31T11:00:00.000'),
    ]);
    final deviceB = deviceSnapshot([
      note(id: 'task-1', title: 'Versión B', updatedAt: '2026-07-31T12:00:00.000'),
    ]);

    final aToServer = pushMutations(previous: const {}, current: deviceA);
    final server = applyMutations(const {}, aToServer);

    final bToServer = pushMutations(previous: server, current: deviceB);
    expect(bToServer.single['operation'], 'UPDATE');
    expect(
      (bToServer.single['payload'] as Map)['title'],
      'Versión B',
    );

    final mergedOnA = applyMutations(deviceA, bToServer);
    expect(mergedOnA['note']!['task-1']!['title'], 'Versión B');
    expect(mergedOnA['note']!.containsKey('conflict-copy'), isFalse);
  });

  test('server conflict copy mutation is ignored on pull apply', () {
    final remoteConflict = {
      'entityType': 'note',
      'entityId': 'conflict-copy',
      'operation': 'CREATE',
      'payload': note(
        id: 'conflict-copy',
        title: 'Conflicto de sincronización · Basura',
        syncConflictOfNoteId: 'task-1',
      ),
    };

    final device = applyMutations(
      deviceSnapshot([note(id: 'task-1', title: 'OK')]),
      [remoteConflict],
    );

    expect(device['note']!.keys, ['task-1']);
  });
}
