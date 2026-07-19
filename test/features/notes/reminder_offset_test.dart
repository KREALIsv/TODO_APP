import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/reminder_offset.dart';

void main() {
  NoteItem task({
    DateTime? dueAt,
    bool dueHasTime = false,
    int? reminderMinutesBefore,
    bool completed = false,
    DateTime? archivedAt,
  }) {
    final now = DateTime(2026, 7, 19, 12);
    return NoteItem(
      id: '1',
      type: NoteType.task,
      title: 'Deploy',
      body: '',
      pinned: false,
      completed: completed,
      createdAt: now,
      updatedAt: now,
      dueAt: dueAt,
      dueHasTime: dueHasTime,
      reminderMinutesBefore: reminderMinutesBefore,
      archivedAt: archivedAt,
    );
  }

  test('legacy map without reminder key loads as null', () {
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
    expect(NoteItem.fromMap(map).reminderMinutesBefore, isNull);
  });

  test('roundtrip preserves reminderMinutesBefore', () {
    final original = task(
      dueAt: DateTime(2026, 7, 20, 10),
      dueHasTime: true,
      reminderMinutesBefore: 60,
    );
    final restored = NoteItem.fromMap(original.toMap());
    expect(restored.reminderMinutesBefore, 60);
  });

  test('fireAt for timed due subtracts offset', () {
    final item = task(
      dueAt: DateTime(2026, 7, 20, 10, 0),
      dueHasTime: true,
      reminderMinutesBefore: 60,
    );
    final fire = ReminderOffset.fireAt(
      item,
      now: DateTime(2026, 7, 19, 12),
    );
    expect(fire, DateTime(2026, 7, 20, 9, 0));
  });

  test('fireAt for all-day uses 09:00 local', () {
    final item = task(
      dueAt: DateTime(2026, 7, 21),
      dueHasTime: false,
      reminderMinutesBefore: 0,
    );
    final fire = ReminderOffset.fireAt(
      item,
      now: DateTime(2026, 7, 19, 12),
    );
    expect(fire, DateTime(2026, 7, 21, 9, 0));
  });

  test('fireAt returns null when in the past', () {
    final item = task(
      dueAt: DateTime(2026, 7, 19, 10, 0),
      dueHasTime: true,
      reminderMinutesBefore: 0,
    );
    final fire = ReminderOffset.fireAt(
      item,
      now: DateTime(2026, 7, 19, 12),
    );
    expect(fire, isNull);
  });

  test('fireAt returns null when completed or archived', () {
    final due = DateTime(2026, 7, 25, 10);
    final completed = task(
      dueAt: due,
      dueHasTime: true,
      reminderMinutesBefore: 60,
      completed: true,
    );
    final archived = task(
      dueAt: due,
      dueHasTime: true,
      reminderMinutesBefore: 60,
      archivedAt: DateTime(2026, 7, 19),
    );
    final now = DateTime(2026, 7, 19, 12);
    expect(ReminderOffset.fireAt(completed, now: now), isNull);
    expect(ReminderOffset.fireAt(archived, now: now), isNull);
  });

  test('labelFor covers presets and none', () {
    expect(ReminderOffset.labelFor(null), 'Ninguno');
    expect(ReminderOffset.labelFor(0), 'En fecha de vencimiento');
    expect(ReminderOffset.labelFor(1440), '1 día antes');
  });
}
