import 'dart:convert';

import '../../notes/domain/note_item.dart';

/// Title prefix used when the client duplicates a note during sync conflict
/// resolution. Kept in one place for detection and cleanup.
const String syncConflictTitlePrefix = 'Conflicto de sincronización · ';

bool mapsEqualForSync(Map<String, dynamic>? first, Map<String, dynamic>? second) {
  if (first == null || second == null) return first == second;
  return jsonEncode(first) == jsonEncode(second);
}

/// Whether applying [remote] should spawn a local conflict copy.
///
/// Conflicts are only created when the user changed [local] since [syncedSnapshot]
/// (start of the current sync) and [remote] is newer. Mutations replayed for the
/// same entity during one pull are ignored — that was the source of mass duplicates
/// after re-login.
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
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  return local.copyWith(
    id: id,
    title: '$syncConflictTitlePrefix${local.displayTitle}',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
