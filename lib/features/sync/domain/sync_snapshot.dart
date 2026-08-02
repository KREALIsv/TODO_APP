import 'dart:convert';

import 'sync_conflict.dart';

typedef SyncMutationPayload = Map<String, dynamic>;

/// Full sync snapshot shape used by [SyncService].
typedef SyncEntitySnapshot = Map<String, Map<String, Map<String, dynamic>>>;

/// Removes conflict copies from a note section of a stored sync snapshot.
Map<String, Map<String, dynamic>> sanitizeSyncNoteSection(
  Map<String, Map<String, dynamic>>? notes,
) {
  if (notes == null) return {};
  return {
    for (final entry in notes.entries)
      if (!isSyncConflictNoteMap(entry.value)) entry.key: entry.value,
  };
}

/// Builds note maps for cloud sync, excluding local-only conflict copies.
Map<String, Map<String, dynamic>> buildSyncNoteSection(
  Iterable<Map<String, dynamic>> noteMaps,
) {
  return {
    for (final map in noteMaps)
      if (!isSyncConflictNoteMap(map)) map['id'] as String: map,
  };
}

/// Sanitizes every section of a persisted sync snapshot.
SyncEntitySnapshot sanitizeSyncSnapshot(SyncEntitySnapshot snapshot) {
  return {
    for (final section in snapshot.entries)
      section.key: section.key == 'note'
          ? sanitizeSyncNoteSection(section.value)
          : Map<String, Map<String, dynamic>>.from(section.value),
  };
}

bool mapsEqualForSyncSnapshot(
  Map<String, dynamic>? first,
  Map<String, dynamic>? second,
) {
  if (first == null || second == null) return first == second;
  return jsonEncode(first) == jsonEncode(second);
}

/// Computes push mutations from previous and current sanitized snapshots.
///
/// Extracted for unit/integration tests and to keep conflict copies out of push.
List<SyncMutationPayload> buildSyncPushMutations({
  required SyncEntitySnapshot previous,
  required SyncEntitySnapshot current,
  required SyncMutationPayload Function({
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
  }) mutationBuilder,
}) {
  final mutations = <SyncMutationPayload>[];
  for (final entityType in current.keys) {
    final before = previous[entityType] ?? const <String, Map<String, dynamic>>{};
    final after = current[entityType] ?? const <String, Map<String, dynamic>>{};
    for (final entry in after.entries) {
      if (mapsEqualForSyncSnapshot(before[entry.key], entry.value)) continue;
      mutations.add(
        mutationBuilder(
          entityType: entityType,
          entityId: entry.key,
          operation: before.containsKey(entry.key) ? 'UPDATE' : 'CREATE',
          payload: entry.value,
        ),
      );
    }
    for (final entityId in before.keys) {
      if (after.containsKey(entityId)) continue;
      mutations.add(
        mutationBuilder(
          entityType: entityType,
          entityId: entityId,
          operation: 'DELETE',
        ),
      );
    }
  }
  return mutations;
}

/// Whether a pulled note mutation should be ignored (remote conflict copy).
bool shouldIgnoreRemoteNoteMutation(Map<String, dynamic> payload) {
  return isSyncConflictNoteMap(payload);
}

/// Note ids that were wrongly persisted in an older sync snapshot.
Iterable<String> conflictCopyIdsInSnapshot(SyncEntitySnapshot snapshot) sync* {
  final notes = snapshot['note'];
  if (notes == null) return;
  for (final entry in notes.entries) {
    if (isSyncConflictNoteMap(entry.value)) yield entry.key;
  }
}

/// Adds DELETE mutations for conflict copies left in legacy stored snapshots.
List<SyncMutationPayload> withConflictCopyCleanupDeletes({
  required SyncEntitySnapshot rawPrevious,
  required List<SyncMutationPayload> mutations,
  required SyncMutationPayload Function({
    required String entityType,
    required String entityId,
    required String operation,
  }) deleteBuilder,
}) {
  final existingDeletes = mutations
      .where(
        (mutation) =>
            mutation['entityType'] == 'note' &&
            mutation['operation'] == 'DELETE',
      )
      .map((mutation) => mutation['entityId'] as String)
      .toSet();

  final result = List<SyncMutationPayload>.from(mutations);
  for (final entityId in conflictCopyIdsInSnapshot(rawPrevious)) {
    if (existingDeletes.contains(entityId)) continue;
    result.add(
      deleteBuilder(
        entityType: 'note',
        entityId: entityId,
        operation: 'DELETE',
      ),
    );
  }
  return result;
}
