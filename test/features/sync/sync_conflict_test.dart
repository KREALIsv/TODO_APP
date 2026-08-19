import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/checklist_item.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/sync/domain/sync_conflict.dart';

NoteItem _task({
  required String id,
  required String title,
  required DateTime updatedAt,
  String body = '',
  bool completed = false,
  DateTime? completedAt,
  String? syncConflictOfNoteId,
  List<ChecklistItem> checklistItems = const [],
  String? checklistTitle,
}) {
  return NoteItem(
    id: id,
    type: NoteType.task,
    title: title,
    body: body,
    pinned: false,
    completed: completed,
    completedAt: completedAt,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    syncConflictOfNoteId: syncConflictOfNoteId,
    checklistTitle: checklistTitle,
    checklistItems: checklistItems,
  );
}

void main() {
  final baseTime = DateTime(2026, 8, 6, 10);

  group('fingerprints', () {
    test('contentEqual ignores completed and updatedAt', () {
      final a = _task(
        id: 'a',
        title: 'Tarea 6 ago',
        updatedAt: baseTime,
      );
      final b = _task(
        id: 'a',
        title: 'Tarea 6 ago',
        updatedAt: baseTime.add(const Duration(hours: 2)),
        completed: true,
        completedAt: baseTime.add(const Duration(hours: 2)),
      );
      expect(contentEqual(a, b), isTrue);
      expect(mergeableStateEqual(a, b), isFalse);
    });

    test('contentEqual detects title/body changes', () {
      final a = _task(id: 'a', title: 'A', body: 'x', updatedAt: baseTime);
      final b = _task(id: 'a', title: 'B', body: 'x', updatedAt: baseTime);
      expect(contentEqual(a, b), isFalse);
    });

    test('checklist item completed is state, not content', () {
      final itemsOpen = [
        const ChecklistItem(id: 'c1', title: 'Sub', completed: false),
      ];
      final itemsDone = [
        const ChecklistItem(id: 'c1', title: 'Sub', completed: true),
      ];
      final a = _task(
        id: 'a',
        title: 'T',
        updatedAt: baseTime,
        checklistTitle: 'Lista',
        checklistItems: itemsOpen,
      );
      final b = _task(
        id: 'a',
        title: 'T',
        updatedAt: baseTime,
        checklistTitle: 'Lista',
        checklistItems: itemsDone,
      );
      expect(contentEqual(a, b), isTrue);
      expect(mergeableStateEqual(a, b), isFalse);
    });
  });

  group('resolveNoteMerge', () {
    test('remote completed only → applyRemote, no conflict', () {
      final base = _task(id: 'a', title: 'Tarea 6 ago', updatedAt: baseTime);
      final local = base;
      final remote = base.copyWith(
        completed: true,
        completedAt: baseTime.add(const Duration(hours: 1)),
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.action, NoteMergeAction.applyRemote);
      expect(result.shouldCreateConflictCopy, isFalse);
      expect(result.note?.completed, isTrue);
    });

    test('local body edit, remote unchanged → keepLocal', () {
      final base = _task(
        id: 'a',
        title: 'T',
        body: 'v1',
        updatedAt: baseTime,
      );
      final local = base.copyWith(
        body: 'v2 local',
        updatedAt: baseTime.add(const Duration(minutes: 5)),
      );
      final remote = base.copyWith(
        updatedAt: baseTime, // still base content
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.action, NoteMergeAction.keepLocal);
      expect(result.shouldCreateConflictCopy, isFalse);
    });

    test('local body edit + remote completed → merged without conflict', () {
      final base = _task(
        id: 'a',
        title: 'T',
        body: 'v1',
        updatedAt: baseTime,
      );
      final local = base.copyWith(
        body: 'v2 local',
        updatedAt: baseTime.add(const Duration(minutes: 5)),
      );
      final remote = base.copyWith(
        completed: true,
        completedAt: baseTime.add(const Duration(hours: 1)),
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.action, NoteMergeAction.merged);
      expect(result.shouldCreateConflictCopy, isFalse);
      expect(result.note?.body, 'v2 local');
      expect(result.note?.completed, isTrue);
    });

    test('both sides edit title differently → conflict', () {
      final base = _task(id: 'a', title: 'A', updatedAt: baseTime);
      final local = base.copyWith(
        title: 'B',
        updatedAt: baseTime.add(const Duration(minutes: 10)),
      );
      final remote = base.copyWith(
        title: 'C',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.action, NoteMergeAction.conflict);
      expect(result.shouldCreateConflictCopy, isTrue);
      expect(result.note?.title, 'C');
    });

    test('both sides edit title to same value → no conflict', () {
      final base = _task(id: 'a', title: 'A', updatedAt: baseTime);
      final local = base.copyWith(
        title: 'B',
        updatedAt: baseTime.add(const Duration(minutes: 10)),
      );
      final remote = base.copyWith(
        title: 'B',
        completed: true,
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.shouldCreateConflictCopy, isFalse);
      expect(result.note?.title, 'B');
      expect(result.note?.completed, isTrue);
    });

    test('only updatedAt differs → keepLocal', () {
      final base = _task(id: 'a', title: 'T', updatedAt: baseTime);
      final local = base.copyWith(
        updatedAt: baseTime.add(const Duration(seconds: 1)),
      );
      final remote = base.copyWith(
        updatedAt: baseTime.add(const Duration(seconds: 2)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      // content+state equal to local after merge (remote state same)
      expect(result.shouldCreateConflictCopy, isFalse);
      expect(
        result.action == NoteMergeAction.keepLocal ||
            result.action == NoteMergeAction.applyRemote,
        isTrue,
      );
    });

    test('entityUpdatedDuringPull always applyRemote', () {
      final base = _task(id: 'a', title: 'V1', updatedAt: baseTime);
      final local = base.copyWith(title: 'V2');
      final remote = base.copyWith(
        title: 'V3',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: true,
      );

      expect(result.action, NoteMergeAction.applyRemote);
      expect(result.shouldCreateConflictCopy, isFalse);
    });

    test('local null → applyRemote', () {
      final remote = _task(id: 'a', title: 'Nueva', updatedAt: baseTime);
      final result = resolveNoteMerge(
        local: null,
        base: null,
        remote: remote,
        entityUpdatedDuringPull: false,
      );
      expect(result.action, NoteMergeAction.applyRemote);
    });

    test('no base + divergent content → conflict once', () {
      final local = _task(id: 'a', title: 'Local', updatedAt: baseTime);
      final remote = _task(
        id: 'a',
        title: 'Remote',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: null,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.action, NoteMergeAction.conflict);
    });

    test('no base + same content remote completed → no conflict', () {
      final local = _task(id: 'a', title: 'T', updatedAt: baseTime);
      final remote = local.copyWith(
        completed: true,
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: null,
        remote: remote,
        entityUpdatedDuringPull: false,
      );

      expect(result.shouldCreateConflictCopy, isFalse);
    });
  });

  group('shouldCreateSyncConflict (compat)', () {
    test('is false when local matches sync snapshot', () {
      final local = _task(id: 'a', title: 'Hola', updatedAt: baseTime);
      expect(
        shouldCreateSyncConflict(
          local: local,
          syncedSnapshot: local.toMap(),
          remote: local.copyWith(
            title: 'Remoto',
            updatedAt: baseTime.add(const Duration(hours: 1)),
          ),
          entityUpdatedDuringPull: false,
        ),
        isFalse,
      );
    });

    test('is false during replay of same entity', () {
      final synced = _task(id: 'a', title: 'V1', updatedAt: baseTime);
      final local = _task(
        id: 'a',
        title: 'V2',
        updatedAt: baseTime.add(const Duration(minutes: 5)),
      );
      final remote = _task(
        id: 'a',
        title: 'V3',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

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

    test('is true for genuine concurrent edit', () {
      final synced = _task(id: 'a', title: 'V1', updatedAt: baseTime);
      final local = _task(
        id: 'a',
        title: 'Edit local',
        updatedAt: baseTime.add(const Duration(minutes: 10)),
      );
      final remote = _task(
        id: 'a',
        title: 'Remoto',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

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

    test('is false when remote only completes same task', () {
      final synced = _task(id: 'a', title: '6 ago', updatedAt: baseTime);
      final local = synced;
      final remote = synced.copyWith(
        completed: true,
        completedAt: baseTime.add(const Duration(days: 1)),
        updatedAt: baseTime.add(const Duration(days: 1)),
      );

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
  });

  group('legacy helpers', () {
    test('isSyncConflictCopy detects metadata and legacy title prefix', () {
      expect(
        isSyncConflictCopy(_task(id: 'a', title: 'Normal', updatedAt: baseTime)),
        isFalse,
      );
      expect(
        isSyncConflictCopy(
          _task(
            id: 'b',
            title: 'Copia',
            updatedAt: baseTime,
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
            updatedAt: baseTime,
          ),
        ),
        isTrue,
      );
    });

    test('buildSyncConflictCopy links to canonical note without title prefix', () {
      final local = _task(id: 'a', title: 'Mi tarea', updatedAt: baseTime);
      final copy = buildSyncConflictCopy(
        local,
        id: 'copy-id',
        originalNoteId: 'a',
        now: baseTime.add(const Duration(days: 1)),
      );

      expect(copy.id, 'copy-id');
      expect(copy.title, 'Mi tarea');
      expect(copy.syncConflictOfNoteId, 'a');
      expect(copy.updatedAt, baseTime.add(const Duration(days: 1)));
    });

    test('mergeConflictLocalOntoCanonical applies local fields', () {
      final canonical = _task(id: 'a', title: 'Nube', updatedAt: baseTime);
      final local = _task(
        id: 'copy',
        title: 'Conflicto de sincronización · Local',
        updatedAt: baseTime.add(const Duration(hours: 1)),
        syncConflictOfNoteId: 'a',
      ).copyWith(body: 'detalle local', completed: true);

      final merged = mergeConflictLocalOntoCanonical(
        canonical: canonical,
        localSnapshot: local,
        now: baseTime.add(const Duration(days: 1)),
      );

      expect(merged.id, 'a');
      expect(merged.title, 'Local');
      expect(merged.body, 'detalle local');
      expect(merged.completed, isTrue);
      expect(merged.syncConflictOfNoteId, isNull);
    });
  });
}
