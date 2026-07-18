import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/task_groups.dart';

void main() {
  final now = DateTime(2026, 7, 16, 15);

  NoteItem task({
    required String id,
    DateTime? dueAt,
    bool dueHasTime = false,
    DateTime? todayAt,
    bool completed = false,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    final created = DateTime(2026, 7, 1);
    return NoteItem(
      id: id,
      type: NoteType.task,
      title: id,
      body: '',
      pinned: false,
      completed: completed,
      createdAt: created,
      updatedAt: updatedAt ?? created,
      dueAt: dueAt,
      dueHasTime: dueHasTime,
      todayAt: todayAt,
      completedAt: completedAt,
    );
  }

  test('overdue incomplete enters Hoy first', () {
    final groups = TaskGroupsQuery.from(
      [
        task(id: 'switch', todayAt: now),
        task(id: 'overdue', dueAt: DateTime(2026, 7, 10)),
        task(id: 'due', dueAt: DateTime(2026, 7, 16)),
      ],
      now: now,
    );
    expect(groups.today.map((e) => e.id).toList(), ['overdue', 'due', 'switch']);
  });

  test('due today with time sorts before due today without time', () {
    final groups = TaskGroupsQuery.from(
      [
        task(id: 'no-time', dueAt: DateTime(2026, 7, 16)),
        task(
          id: 'with-time',
          dueAt: DateTime(2026, 7, 16, 10),
          dueHasTime: true,
        ),
      ],
      now: now,
    );
    expect(groups.today.map((e) => e.id).toList(), ['with-time', 'no-time']);
  });

  test('expired todayAt does not enter Hoy', () {
    final groups = TaskGroupsQuery.from(
      [task(id: 'old', todayAt: DateTime(2026, 7, 15, 18))],
      now: now,
    );
    expect(groups.today, isEmpty);
    expect(groups.undated.map((e) => e.id), ['old']);
  });

  test('completed today stays in Hoy and counts in progress', () {
    final groups = TaskGroupsQuery.from(
      [
        task(
          id: 'done',
          dueAt: DateTime(2026, 7, 16),
          completed: true,
          completedAt: DateTime(2026, 7, 16, 12),
        ),
        task(id: 'open', dueAt: DateTime(2026, 7, 16)),
      ],
      now: now,
    );
    expect(groups.today.map((e) => e.id).toList(), ['open', 'done']);
    expect(groups.progress.done, 1);
    expect(groups.progress.total, 2);
    expect(groups.progress.hideIfZero, isFalse);
  });

  test('overdue completed leaves Hoy', () {
    final groups = TaskGroupsQuery.from(
      [
        task(
          id: 'paid',
          dueAt: DateTime(2026, 7, 10),
          completed: true,
          completedAt: DateTime(2026, 7, 16, 12),
        ),
      ],
      now: now,
    );
    expect(groups.today, isEmpty);
    expect(groups.completedEarlier.map((e) => e.id), ['paid']);
  });

  test('badge 0/0 is hideIfZero', () {
    final progress = TaskGroupsQuery.progressFor([]);
    expect(progress.hideIfZero, isTrue);
    expect(progress.done, 0);
    expect(progress.total, 0);
  });

  test('upcoming and undated empty when no matching tasks', () {
    final groups = TaskGroupsQuery.from(
      [task(id: 'today', dueAt: DateTime(2026, 7, 16))],
      now: now,
    );
    expect(groups.upcoming, isEmpty);
    expect(groups.undated, isEmpty);
    expect(groups.completedEarlier, isEmpty);
  });

  test('upcoming sorts by dueAt ascending', () {
    final groups = TaskGroupsQuery.from(
      [
        task(id: 'later', dueAt: DateTime(2026, 7, 25)),
        task(id: 'sooner', dueAt: DateTime(2026, 7, 20)),
      ],
      now: now,
    );
    expect(groups.upcoming.map((e) => e.id).toList(), ['sooner', 'later']);
  });

  test('undated excludes today commitment', () {
    final groups = TaskGroupsQuery.from(
      [
        task(id: 'inbox', dueAt: null),
        task(id: 'today', todayAt: now),
      ],
      now: now,
    );
    expect(groups.undated.map((e) => e.id), ['inbox']);
    expect(groups.today.map((e) => e.id), ['today']);
  });

  test('notes are ignored', () {
    final note = NoteItem(
      id: 'n',
      type: NoteType.note,
      title: 'n',
      body: '',
      pinned: false,
      completed: false,
      createdAt: now,
      updatedAt: now,
      dueAt: DateTime(2026, 7, 16),
    );
    final groups = TaskGroupsQuery.from([note], now: now);
    expect(groups.isEmpty, isTrue);
  });

  test('isComplete when all today done', () {
    final groups = TaskGroupsQuery.from(
      [
        task(
          id: 'a',
          dueAt: DateTime(2026, 7, 16),
          completed: true,
          completedAt: now,
        ),
      ],
      now: now,
    );
    expect(groups.progress.isComplete, isTrue);
  });

  test('multiple overdue sorted oldest first', () {
    final groups = TaskGroupsQuery.from(
      [
        task(id: 'newer', dueAt: DateTime(2026, 7, 14)),
        task(id: 'older', dueAt: DateTime(2026, 7, 8)),
      ],
      now: now,
    );
    expect(groups.today.map((e) => e.id).toList(), ['older', 'newer']);
  });

  test('due today with earlier time before later time', () {
    final groups = TaskGroupsQuery.from(
      [
        task(
          id: 'pm',
          dueAt: DateTime(2026, 7, 16, 18),
          dueHasTime: true,
        ),
        task(
          id: 'am',
          dueAt: DateTime(2026, 7, 16, 9),
          dueHasTime: true,
        ),
      ],
      now: now,
    );
    expect(groups.today.map((e) => e.id).toList(), ['am', 'pm']);
  });

  test('completed earlier sorted by completedAt desc', () {
    final groups = TaskGroupsQuery.from(
      [
        task(
          id: 'old',
          completed: true,
          completedAt: DateTime(2026, 7, 10),
        ),
        task(
          id: 'new',
          completed: true,
          completedAt: DateTime(2026, 7, 14),
        ),
      ],
      now: now,
    );
    expect(groups.completedEarlier.map((e) => e.id).toList(), ['new', 'old']);
  });

  test('archived tasks ignored', () {
    final archived = task(id: 'a', dueAt: DateTime(2026, 7, 16)).copyWith(
      archivedAt: now,
    );
    final groups = TaskGroupsQuery.from([archived], now: now);
    expect(groups.isEmpty, isTrue);
  });
}
