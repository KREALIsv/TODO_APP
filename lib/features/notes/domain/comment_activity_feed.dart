import 'day_entry.dart';
import 'note_audit_event.dart';
import 'note_comment.dart';

enum CommentFeedKind { comment, dayEntry, audit }

class CommentFeedItem {
  const CommentFeedItem.comment(this.comment)
      : kind = CommentFeedKind.comment,
        dayEntry = null,
        audit = null;

  const CommentFeedItem.dayEntry(this.dayEntry)
      : kind = CommentFeedKind.dayEntry,
        comment = null,
        audit = null;

  const CommentFeedItem.audit(this.audit)
      : kind = CommentFeedKind.audit,
        comment = null,
        dayEntry = null;

  final CommentFeedKind kind;
  final NoteComment? comment;
  final DayEntry? dayEntry;
  final NoteAuditEvent? audit;

  DateTime get sortAt {
    return switch (kind) {
      CommentFeedKind.comment => comment!.createdAt,
      CommentFeedKind.dayEntry => dayEntry!.outcomeAt ?? dayEntry!.createdAt,
      CommentFeedKind.audit => audit!.createdAt,
    };
  }
}

int _kindRank(CommentFeedKind kind) {
  return switch (kind) {
    CommentFeedKind.comment => 0,
    CommentFeedKind.audit => 1,
    CommentFeedKind.dayEntry => 2,
  };
}

List<CommentFeedItem> buildCommentActivityFeed({
  required List<NoteComment> comments,
  required List<DayEntry> dayEntries,
  required List<NoteAuditEvent> audits,
  required bool hideDetails,
}) {
  final items = <CommentFeedItem>[
    for (final comment in comments) CommentFeedItem.comment(comment),
    if (!hideDetails) ...[
      for (final entry in dayEntries) CommentFeedItem.dayEntry(entry),
      for (final event in audits) CommentFeedItem.audit(event),
    ],
  ];
  items.sort((a, b) {
    final timeCmp = b.sortAt.compareTo(a.sortAt);
    if (timeCmp != 0) return timeCmp;
    return _kindRank(a.kind).compareTo(_kindRank(b.kind));
  });
  return items;
}
