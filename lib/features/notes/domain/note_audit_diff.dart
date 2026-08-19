import 'checklist_item.dart';
import 'note_audit_event.dart';
import 'note_item.dart';

List<NoteAuditKind> diffNoteAudits(NoteItem? previous, NoteItem next) {
  if (previous == null) {
    if (next.type == NoteType.note) return const [NoteAuditKind.created];
    return const [];
  }

  final kinds = <NoteAuditKind>[];
  if (previous.title != next.title) kinds.add(NoteAuditKind.titleChanged);
  if (previous.body != next.body) kinds.add(NoteAuditKind.bodyChanged);
  if (!_sameStringList(previous.tags, next.tags)) {
    kinds.add(NoteAuditKind.tagsChanged);
  }
  if (previous.reminderMinutesBefore != next.reminderMinutesBefore) {
    kinds.add(NoteAuditKind.reminderChanged);
  }
  if (previous.archivedAt == null && next.archivedAt != null) {
    kinds.add(NoteAuditKind.archived);
  } else if (previous.archivedAt != null && next.archivedAt == null) {
    kinds.add(NoteAuditKind.restored);
  }
  if (previous.type != next.type) kinds.add(NoteAuditKind.typeChanged);
  if (previous.pinned != next.pinned) kinds.add(NoteAuditKind.pinnedChanged);
  if (previous.checklistTitle != next.checklistTitle ||
      !_sameChecklist(previous.checklistItems, next.checklistItems)) {
    kinds.add(NoteAuditKind.checklistChanged);
  }
  if (previous.coverAttachmentId != next.coverAttachmentId) {
    kinds.add(NoteAuditKind.coverChanged);
  }
  return kinds;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameChecklist(List<ChecklistItem> a, List<ChecklistItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].title != b[i].title ||
        a[i].completed != b[i].completed) {
      return false;
    }
  }
  return true;
}
