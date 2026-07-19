import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/task_dates.dart';
import 'package:todos_app/features/notes/domain/task_groups.dart';

void main() {
  test('timed due crossing now moves task rank to overdue in Hoy', () {
    final task = NoteItem(
      id: 'nuva',
      type: NoteType.task,
      title: 'NUVA',
      body: '',
      pinned: false,
      completed: false,
      createdAt: DateTime(2026, 7, 19, 8, 0),
      updatedAt: DateTime(2026, 7, 19, 8, 0),
      dueAt: DateTime(2026, 7, 19, 8, 56),
      dueHasTime: true,
    );

    final before = TaskGroupsQuery.from(
      [task],
      now: DateTime(2026, 7, 19, 8, 55),
    );
    expect(before.today.single.isOverdue(DateTime(2026, 7, 19, 8, 55)), isFalse);

    final after = TaskGroupsQuery.from(
      [task],
      now: DateTime(2026, 7, 19, 8, 57),
    );
    expect(after.today.single.isOverdue(DateTime(2026, 7, 19, 8, 57)), isTrue);
  });
}
