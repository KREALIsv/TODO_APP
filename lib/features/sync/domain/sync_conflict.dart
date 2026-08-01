import 'dart:convert';

import '../../notes/domain/note_item.dart';

/// Legacy title prefix from releases before metadata-based conflict copies.
const String syncConflictTitlePrefix = 'Conflicto de sincronización · ';

class SyncConflictPair {
  const SyncConflictPair({
    required this.copy,
    required this.canonical,
  });

  final NoteItem copy;
  final NoteItem? canonical;

  bool get hasLinkedCanonical => canonical != null;
}

bool mapsEqualForSync(Map<String, dynamic>? first, Map<String, dynamic>? second) {
  if (first == null || second == null) return first == second;
  return jsonEncode(first) == jsonEncode(second);
}

bool isSyncConflictCopy(NoteItem item) {
  return item.syncConflictOfNoteId != null ||
      item.title.startsWith(syncConflictTitlePrefix);
}

/// Detects conflict copies in serialized note maps (sync payloads / snapshots).
bool isSyncConflictNoteMap(Map<String, dynamic> map) {
  final link = map['syncConflictOfNoteId'];
  if (link is String && link.isNotEmpty) return true;
  final title = map['title'];
  return title is String && title.startsWith(syncConflictTitlePrefix);
}

String conflictCopyLabel(NoteItem copy) {
  if (copy.title.startsWith(syncConflictTitlePrefix)) {
    return copy.title.substring(syncConflictTitlePrefix.length).trim();
  }
  return copy.displayTitle;
}

String stripConflictTitlePrefix(String title) {
  if (!title.startsWith(syncConflictTitlePrefix)) return title;
  return title.substring(syncConflictTitlePrefix.length).trim();
}

/// Whether applying [remote] should spawn a local conflict copy.
bool shouldCreateSyncConflict({
  required NoteItem? local,
  required Map<String, dynamic>? syncedSnapshot,
  required NoteItem remote,
  required bool entityUpdatedDuringPull,
}) {
  if (local == null || syncedSnapshot == null) return false;
  if (entityUpdatedDuringPull) return false;
  if (mapsEqualForSync(local.toMap(), syncedSnapshot)) return false;
  return remote.updatedAt.isAfter(local.updatedAt);
}

NoteItem buildSyncConflictCopy(
  NoteItem local, {
  required String id,
  required String originalNoteId,
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  return local.copyWith(
    id: id,
    syncConflictOfNoteId: originalNoteId,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

NoteItem clearSyncConflictMetadata(NoteItem item) {
  final title = stripConflictTitlePrefix(item.title);
  return item.copyWith(
    title: title.isNotEmpty ? title : item.displayTitle,
    syncConflictOfNoteId: null,
  );
}

/// Applies the local snapshot from a conflict copy onto the canonical note.
NoteItem mergeConflictLocalOntoCanonical({
  required NoteItem canonical,
  required NoteItem localSnapshot,
  required DateTime now,
}) {
  final cleaned = clearSyncConflictMetadata(localSnapshot);
  return canonical.copyWith(
    type: cleaned.type,
    title: cleaned.title,
    body: cleaned.body,
    pinned: cleaned.pinned,
    completed: cleaned.completed,
    tags: cleaned.tags,
    dueAt: cleaned.dueAt,
    dueHasTime: cleaned.dueHasTime,
    todayAt: cleaned.todayAt,
    completedAt: cleaned.completedAt,
    archivedAt: cleaned.archivedAt,
    reminderMinutesBefore: cleaned.reminderMinutesBefore,
    coverAttachmentId: cleaned.coverAttachmentId,
    updatedAt: now,
    syncConflictOfNoteId: null,
  );
}
