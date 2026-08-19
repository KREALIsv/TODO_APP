import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/note_audit_diff.dart';
import 'package:todos_app/features/notes/domain/note_audit_event.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

NoteItem _note({
  String title = 'Título',
  String body = 'Cuerpo',
  List<String> tags = const [],
  bool pinned = false,
  bool completed = false,
  DateTime? dueAt,
  DateTime? todayAt,
  DateTime? archivedAt,
  String? coverAttachmentId,
  NoteType type = NoteType.note,
}) {
  final now = DateTime(2026, 8, 19, 10);
  return NoteItem(
    id: 'n1',
    type: type,
    title: title,
    body: body,
    pinned: pinned,
    completed: completed,
    createdAt: now,
    updatedAt: now,
    tags: tags,
    dueAt: dueAt,
    todayAt: todayAt,
    archivedAt: archivedAt,
    coverAttachmentId: coverAttachmentId,
  );
}

void main() {
  test('new note records created; new task does not', () {
    expect(
      diffNoteAudits(null, _note()),
      [NoteAuditKind.created],
    );
    expect(
      diffNoteAudits(null, _note(type: NoteType.task)),
      isEmpty,
    );
  });

  test('title and tags produce two audits', () {
    final kinds = diffNoteAudits(
      _note(),
      _note(title: 'Otro', tags: ['x']),
    );
    expect(kinds, [
      NoteAuditKind.titleChanged,
      NoteAuditKind.tagsChanged,
    ]);
  });

  test('completed due and today do not emit audits', () {
    final previous = _note(type: NoteType.task);
    final next = _note(
      type: NoteType.task,
      completed: true,
      dueAt: DateTime(2026, 8, 20),
      todayAt: DateTime(2026, 8, 19, 12),
    );
    expect(diffNoteAudits(previous, next), isEmpty);
  });

  test('updatedAt-only change emits no audits', () {
    final previous = _note();
    final next = previous.copyWith(updatedAt: DateTime(2026, 8, 19, 12));
    expect(diffNoteAudits(previous, next), isEmpty);
  });

  test('cover change emits coverChanged', () {
    expect(
      diffNoteAudits(_note(), _note(coverAttachmentId: 'a1')),
      [NoteAuditKind.coverChanged],
    );
  });
}
