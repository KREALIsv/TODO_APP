import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/sync/domain/sync_conflict.dart';

/// Regression: reconnect after session expiry must not mass-create conflicts
/// when notes share the same id and only fuseable state diverged.
void main() {
  final day = DateTime(2026, 8, 6, 9);

  NoteItem note({
    required String id,
    required String title,
    required DateTime updatedAt,
    String body = '',
    bool completed = false,
  }) {
    return NoteItem(
      id: id,
      type: NoteType.task,
      title: title,
      body: body,
      pinned: false,
      completed: completed,
      createdAt: day,
      updatedAt: updatedAt,
    );
  }

  test('reconnect matrix: many notes state-only remote → zero conflicts', () {
    final ids = List.generate(20, (i) => 'task-$i');
    var conflictCount = 0;

    for (final id in ids) {
      final base = note(
        id: id,
        title: 'Nota $id',
        updatedAt: day,
      );
      // Device unchanged since last sync (typical after 401 with no local edits).
      final local = base;
      final remote = base.copyWith(
        completed: id.hashCode.isEven,
        updatedAt: day.add(Duration(hours: id.hashCode % 5 + 1)),
      );

      final result = resolveNoteMerge(
        local: local,
        base: base,
        remote: remote,
        entityUpdatedDuringPull: false,
      );
      if (result.shouldCreateConflictCopy) conflictCount++;
    }

    expect(conflictCount, 0);
  });

  test('reconnect: one real title clash → exactly one conflict', () {
    final results = <NoteMergeResult>[];

    for (var i = 0; i < 10; i++) {
      final id = 'n-$i';
      final base = note(id: id, title: 'T$i', updatedAt: day);
      final local = i == 3
          ? base.copyWith(
              title: 'Local edit',
              updatedAt: day.add(const Duration(minutes: 3)),
            )
          : base;
      final remote = i == 3
          ? base.copyWith(
              title: 'Remote edit',
              updatedAt: day.add(const Duration(hours: 2)),
            )
          : base.copyWith(
              completed: true,
              updatedAt: day.add(const Duration(hours: 1)),
            );

      results.add(
        resolveNoteMerge(
          local: local,
          base: base,
          remote: remote,
          entityUpdatedDuringPull: false,
        ),
      );
    }

    final conflicts =
        results.where((r) => r.shouldCreateConflictCopy).toList();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.note?.title, 'Remote edit');
  });

  test('history replay on same id never multiplies conflicts', () {
    final base = note(id: 'a', title: 'V0', updatedAt: day);
    final local = base.copyWith(
      title: 'Local divergent',
      updatedAt: day.add(const Duration(minutes: 1)),
    );

    // First historical mutation would conflict; subsequent ones must not.
    final first = resolveNoteMerge(
      local: local,
      base: base,
      remote: note(
        id: 'a',
        title: 'V1 remote',
        updatedAt: day.add(const Duration(hours: 1)),
      ),
      entityUpdatedDuringPull: false,
    );
    expect(first.shouldCreateConflictCopy, isTrue);

    final second = resolveNoteMerge(
      local: first.note,
      base: base,
      remote: note(
        id: 'a',
        title: 'V2 remote',
        updatedAt: day.add(const Duration(hours: 2)),
      ),
      entityUpdatedDuringPull: true,
    );
    expect(second.shouldCreateConflictCopy, isFalse);
  });
}
