import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/notes_query.dart';
import 'package:todos_app/features/notes/domain/task_day_query.dart';
import 'package:todos_app/features/notes/domain/task_groups.dart';

void main() {
  final today = DateTime(2026, 8, 2, 15);
  final tomorrow = DateTime(2026, 8, 3);

  NoteItem task({
    required String id,
    DateTime? createdAt,
    DateTime? dueAt,
    DateTime? todayAt,
    bool completed = false,
    DateTime? completedAt,
  }) {
    final created = createdAt ?? today;
    return NoteItem(
      id: id,
      type: NoteType.task,
      title: id,
      body: '',
      pinned: false,
      completed: completed,
      createdAt: created,
      updatedAt: created,
      dueAt: dueAt,
      todayAt: todayAt,
      completedAt: completedAt,
    );
  }

  group('TaskDayQuery.isInboxCaptureOn', () {
    test('true for undated task created that day', () {
      expect(
        TaskDayQuery.isInboxCaptureOn(task(id: 'a'), today),
        isTrue,
      );
    });

    test('false when scheduled for another day', () {
      expect(
        TaskDayQuery.isInboxCaptureOn(
          task(id: 'a', dueAt: tomorrow),
          today,
        ),
        isFalse,
      );
    });
  });

  group('Del día vs Hoy alignment', () {
    test('inbox capture today appears in both Del día and Hoy', () {
      final item = task(id: 'inbox');
      expect(NotesQuery.belongsToDay(item, today, now: today), isTrue);
      expect(TaskDayQuery.belongsToHoy(item, now: today), isTrue);
      expect(
        TaskGroupsQuery.belongsToToday(item, now: today),
        isTrue,
      );
    });

    test('scheduled tomorrow appears only on tomorrow Del día, not Hoy', () {
      final item = task(id: 'future', dueAt: tomorrow);
      expect(NotesQuery.belongsToDay(item, today, now: today), isFalse);
      expect(TaskDayQuery.belongsToHoy(item, now: today), isFalse);
      expect(NotesQuery.belongsToDay(item, tomorrow, now: today), isTrue);
    });

    test('expired todayAt is not inbox on today', () {
      final item = task(
        id: 'stale',
        createdAt: DateTime(2026, 7, 28),
        todayAt: DateTime(2026, 8, 1),
      );
      expect(TaskDayQuery.isInboxCaptureOn(item, today), isFalse);
      expect(TaskDayQuery.belongsToHoy(item, now: today), isFalse);
    });

    test('inbox capture does not appear on past day replay', () {
      final past = DateTime(2026, 7, 31);
      final now = DateTime(2026, 8, 4);
      final item = task(
        id: 'inbox-past',
        createdAt: past,
      );
      expect(NotesQuery.belongsToDay(item, past, now: now), isFalse);
      final todayItem = task(id: 'inbox-today', createdAt: now);
      expect(NotesQuery.belongsToDay(todayItem, now, now: now), isTrue);
    });
  });
}
