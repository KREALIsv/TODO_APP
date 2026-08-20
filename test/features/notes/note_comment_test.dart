import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/comment_activity_feed.dart';
import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/note_attachment.dart';
import 'package:todos_app/features/notes/domain/note_audit_event.dart';
import 'package:todos_app/features/notes/domain/note_comment.dart';

void main() {
  test('NoteComment fromMap loads without editedAt', () {
    final comment = NoteComment.fromMap({
      'id': 'c1',
      'noteId': 'n1',
      'body': 'Hola',
      'createdAt': '2026-08-19T10:00:00.000',
    });
    expect(comment.id, 'c1');
    expect(comment.body, 'Hola');
    expect(comment.editedAt, isNull);
    expect(comment.hasText, isTrue);
  });

  test('NoteComment roundtrip keeps editedAt', () {
    final original = NoteComment(
      id: 'c1',
      noteId: 'n1',
      body: 'Texto',
      createdAt: DateTime(2026, 8, 19, 10),
      editedAt: DateTime(2026, 8, 19, 11),
    );
    final restored = NoteComment.fromMap(original.toMap());
    expect(restored.editedAt, original.editedAt);
  });

  test('NoteAttachment fromMap loads without commentId', () {
    final item = NoteAttachment.fromMap({
      'id': 'a1',
      'noteId': 'n1',
      'fileName': 'shot.png',
      'mimeType': 'image/png',
      'byteSize': 12,
      'createdAt': '2026-08-19T10:00:00.000',
      'sortOrder': 0,
    });
    expect(item.commentId, isNull);
  });

  test('NoteAuditEvent fromMap loads without summary', () {
    final event = NoteAuditEvent.fromMap({
      'id': 'e1',
      'noteId': 'n1',
      'kind': 'titleChanged',
      'createdAt': '2026-08-19T10:00:00.000',
    });
    expect(event.summary, isNull);
    expect(event.displaySummary, 'Título actualizado');
  });

  test('feed sorts mixed items newest first', () {
    final t1 = DateTime(2026, 8, 19, 10);
    final t2 = DateTime(2026, 8, 19, 11);
    final t3 = DateTime(2026, 8, 19, 12);
    final items = buildCommentActivityFeed(
      comments: [
        NoteComment(
          id: 'c1',
          noteId: 'n1',
          body: 'nuevo',
          createdAt: t3,
        ),
      ],
      dayEntries: [
        DayEntry(
          id: 'd1',
          noteId: 'n1',
          day: dateOnly(t1),
          via: DayVia.todaySwitch,
          outcome: DayOutcome.open,
          createdAt: t1,
        ),
      ],
      audits: [
        NoteAuditEvent(
          id: 'a1',
          noteId: 'n1',
          kind: NoteAuditKind.titleChanged,
          createdAt: t2,
        ),
      ],
      hideDetails: false,
    );
    expect(items.map((e) => e.kind).toList(), [
      CommentFeedKind.comment,
      CommentFeedKind.audit,
      CommentFeedKind.dayEntry,
    ]);
  });

  test('hideDetails drops day entries and audits', () {
    final now = DateTime(2026, 8, 19, 10);
    final items = buildCommentActivityFeed(
      comments: [
        NoteComment(
          id: 'c1',
          noteId: 'n1',
          body: 'queda',
          createdAt: now,
        ),
      ],
      dayEntries: [
        DayEntry(
          id: 'd1',
          noteId: 'n1',
          day: dateOnly(now),
          via: DayVia.todaySwitch,
          outcome: DayOutcome.open,
          createdAt: now,
        ),
      ],
      audits: [
        NoteAuditEvent(
          id: 'a1',
          noteId: 'n1',
          kind: NoteAuditKind.bodyChanged,
          createdAt: now,
        ),
      ],
      hideDetails: true,
    );
    expect(items, hasLength(1));
    expect(items.single.kind, CommentFeedKind.comment);
  });

  test('equal timestamps prefer comment over audit over dayEntry', () {
    final now = DateTime(2026, 8, 19, 10);
    final items = buildCommentActivityFeed(
      comments: [
        NoteComment(
          id: 'c1',
          noteId: 'n1',
          body: 'comentario',
          createdAt: now,
        ),
      ],
      dayEntries: [
        DayEntry(
          id: 'd1',
          noteId: 'n1',
          day: dateOnly(now),
          via: DayVia.todaySwitch,
          outcome: DayOutcome.open,
          createdAt: now,
          outcomeAt: now,
        ),
      ],
      audits: [
        NoteAuditEvent(
          id: 'a1',
          noteId: 'n1',
          kind: NoteAuditKind.created,
          createdAt: now,
        ),
      ],
      hideDetails: false,
    );
    expect(items.map((e) => e.kind).toList(), [
      CommentFeedKind.comment,
      CommentFeedKind.audit,
      CommentFeedKind.dayEntry,
    ]);
  });
}
