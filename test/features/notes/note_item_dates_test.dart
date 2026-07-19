import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/task_dates.dart';

void main() {
  NoteItem buildItem({
    NoteType type = NoteType.task,
    DateTime? dueAt,
    bool dueHasTime = false,
    DateTime? todayAt,
    DateTime? completedAt,
    DateTime? archivedAt,
    bool completed = false,
  }) {
    final now = DateTime(2026, 7, 16, 12);
    return NoteItem(
      id: '1',
      type: type,
      title: 'T',
      body: 'B',
      pinned: false,
      completed: completed,
      createdAt: now,
      updatedAt: now,
      dueAt: dueAt,
      dueHasTime: dueHasTime,
      todayAt: todayAt,
      completedAt: completedAt,
      archivedAt: archivedAt,
    );
  }

  test('legacy map without date keys loads with nulls', () {
    final map = <String, dynamic>{
      'id': 'legacy',
      'type': 'task',
      'title': 'Old',
      'body': '',
      'pinned': false,
      'completed': false,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    };
    final item = NoteItem.fromMap(map);
    expect(item.dueAt, isNull);
    expect(item.dueHasTime, isFalse);
    expect(item.todayAt, isNull);
    expect(item.completedAt, isNull);
    expect(item.archivedAt, isNull);
    expect(item.reminderMinutesBefore, isNull);
  });

  test('roundtrip preserves optional dates', () {
    final original = buildItem(
      dueAt: DateTime(2026, 7, 20, 10),
      dueHasTime: true,
      todayAt: DateTime(2026, 7, 16, 9),
      completedAt: DateTime(2026, 7, 16, 11),
    ).copyWith(reminderMinutesBefore: 1440);
    final restored = NoteItem.fromMap(original.toMap());
    expect(restored.dueAt, original.dueAt);
    expect(restored.dueHasTime, isTrue);
    expect(restored.todayAt, original.todayAt);
    expect(restored.completedAt, original.completedAt);
    expect(restored.reminderMinutesBefore, 1440);
  });

  test('copyWith can clear nullable dates', () {
    final item = buildItem(
      dueAt: DateTime(2026, 7, 20),
      todayAt: DateTime(2026, 7, 16),
      completedAt: DateTime(2026, 7, 16),
      archivedAt: DateTime(2026, 7, 15),
    );
    final cleared = item.copyWith(
      dueAt: null,
      todayAt: null,
      completedAt: null,
      archivedAt: null,
    );
    expect(cleared.dueAt, isNull);
    expect(cleared.todayAt, isNull);
    expect(cleared.completedAt, isNull);
    expect(cleared.archivedAt, isNull);
  });

  test('isTodayCommitment expires next day', () {
    final item = buildItem(todayAt: DateTime(2026, 7, 15, 18));
    expect(item.isTodayCommitment(DateTime(2026, 7, 15, 23)), isTrue);
    expect(item.isTodayCommitment(DateTime(2026, 7, 16, 1)), isFalse);
  });

  test('isOverdue only for incomplete past due', () {
    final overdue = buildItem(dueAt: DateTime(2026, 7, 10));
    final done = buildItem(
      dueAt: DateTime(2026, 7, 10),
      completed: true,
    );
    final today = DateTime(2026, 7, 16);
    expect(overdue.isOverdue(today), isTrue);
    expect(done.isOverdue(today), isFalse);
  });

  test('isOverdue with time uses full timestamp same day', () {
    final timed = buildItem(
      dueAt: DateTime(2026, 7, 19, 8, 56),
      dueHasTime: true,
    );
    expect(
      timed.isOverdue(DateTime(2026, 7, 19, 8, 55)),
      isFalse,
    );
    expect(
      timed.isOverdue(DateTime(2026, 7, 19, 8, 56)),
      isTrue,
    );
  });

  test('isOverdue without time ignores clock within the day', () {
    final allDay = buildItem(dueAt: DateTime(2026, 7, 19));
    expect(
      allDay.isOverdue(DateTime(2026, 7, 19, 23, 59)),
      isFalse,
    );
    expect(
      allDay.isOverdue(DateTime(2026, 7, 20, 0, 1)),
      isTrue,
    );
  });

  test('clearTaskDates resets business fields', () {
    final item = buildItem(
      dueAt: DateTime(2026, 7, 20),
      dueHasTime: true,
      todayAt: DateTime(2026, 7, 16),
      completedAt: DateTime(2026, 7, 16),
      completed: true,
    ).copyWith(reminderMinutesBefore: 60);
    final cleared = item.clearTaskDates();
    expect(cleared.dueAt, isNull);
    expect(cleared.dueHasTime, isFalse);
    expect(cleared.todayAt, isNull);
    expect(cleared.completedAt, isNull);
    expect(cleared.completed, isFalse);
    expect(cleared.reminderMinutesBefore, isNull);
  });
}
