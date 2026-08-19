import 'dart:convert';

import '../../notes/domain/checklist_item.dart';
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

/// Outcome of three-way note merge on pull (see TRD-sync-conflict-content-merge).
enum NoteMergeAction {
  /// Save [NoteMergeResult.note] (typically remote / fast-forward).
  applyRemote,

  /// Leave Hive unchanged; local already has the right content.
  keepLocal,

  /// Save field-merged [NoteMergeResult.note] (content + fuseable state).
  merged,

  /// Persist a local conflict copy, then save [NoteMergeResult.note] as canonical.
  conflict,
}

class NoteMergeResult {
  const NoteMergeResult({
    required this.action,
    this.note,
  });

  final NoteMergeAction action;

  /// Canonical note to persist for [NoteMergeAction.applyRemote],
  /// [NoteMergeAction.merged], or [NoteMergeAction.conflict].
  final NoteItem? note;

  bool get shouldCreateConflictCopy => action == NoteMergeAction.conflict;
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

/// Semantic content that may produce a conflict UI (title/body/checklist text).
Map<String, dynamic> noteContentFingerprint(NoteItem note) {
  return {
    'title': note.title,
    'body': note.body,
    'checklistTitle': note.checklistTitle,
    'checklistItems': [
      for (final item in _sortedChecklist(note.checklistItems))
        {
          'id': item.id,
          'title': item.title,
          'sortOrder': item.sortOrder,
        },
    ],
  };
}

/// Fuseable state that auto-merges without conflict UI.
Map<String, dynamic> noteMergeableStateFingerprint(NoteItem note) {
  final tags = [...note.tags]..sort();
  return {
    'completed': note.completed,
    'completedAt': note.completedAt?.toIso8601String(),
    'pinned': note.pinned,
    'dueAt': note.dueAt?.toIso8601String(),
    'dueHasTime': note.dueHasTime,
    'todayAt': note.todayAt?.toIso8601String(),
    'archivedAt': note.archivedAt?.toIso8601String(),
    'reminderMinutesBefore': note.reminderMinutesBefore,
    'tags': tags,
    'coverAttachmentId': note.coverAttachmentId,
    'checklistCompleted': {
      for (final item in note.checklistItems) item.id: item.completed,
    },
  };
}

bool contentEqual(NoteItem a, NoteItem b) {
  return mapsEqualForSync(noteContentFingerprint(a), noteContentFingerprint(b));
}

bool mergeableStateEqual(NoteItem a, NoteItem b) {
  return mapsEqualForSync(
    noteMergeableStateFingerprint(a),
    noteMergeableStateFingerprint(b),
  );
}

/// Three-way merge keyed by note [id]. [base] is the last successful sync snapshot.
NoteMergeResult resolveNoteMerge({
  required NoteItem? local,
  required NoteItem? base,
  required NoteItem remote,
  required bool entityUpdatedDuringPull,
}) {
  if (local == null) {
    return NoteMergeResult(action: NoteMergeAction.applyRemote, note: remote);
  }
  if (entityUpdatedDuringPull) {
    return NoteMergeResult(action: NoteMergeAction.applyRemote, note: remote);
  }

  if (_hasContentConflict(base: base, local: local, remote: remote)) {
    return NoteMergeResult(
      action: NoteMergeAction.conflict,
      note: remote,
    );
  }

  final merged = _buildMergedNote(base: base, local: local, remote: remote);
  if (_sameNoteIgnoringUpdatedAt(merged, local)) {
    return const NoteMergeResult(action: NoteMergeAction.keepLocal);
  }
  if (_sameNoteIgnoringUpdatedAt(merged, remote)) {
    return NoteMergeResult(action: NoteMergeAction.applyRemote, note: remote);
  }
  return NoteMergeResult(action: NoteMergeAction.merged, note: merged);
}

/// Legacy helper — prefers [resolveNoteMerge] for new call sites.
bool shouldCreateSyncConflict({
  required NoteItem? local,
  required Map<String, dynamic>? syncedSnapshot,
  required NoteItem remote,
  required bool entityUpdatedDuringPull,
}) {
  NoteItem? base;
  if (syncedSnapshot != null) {
    try {
      base = NoteItem.fromMap(syncedSnapshot);
    } catch (_) {
      base = null;
    }
  }
  return resolveNoteMerge(
    local: local,
    base: base,
    remote: remote,
    entityUpdatedDuringPull: entityUpdatedDuringPull,
  ).shouldCreateConflictCopy;
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
    checklistTitle: cleaned.checklistTitle,
    checklistItems: cleaned.checklistItems,
    updatedAt: now,
    syncConflictOfNoteId: null,
  );
}

bool _hasContentConflict({
  required NoteItem? base,
  required NoteItem local,
  required NoteItem remote,
}) {
  if (contentEqual(local, remote)) return false;
  if (base == null) return true;
  final localChanged = !contentEqual(local, base);
  final remoteChanged = !contentEqual(remote, base);
  return localChanged && remoteChanged;
}

NoteItem _contentSource({
  required NoteItem? base,
  required NoteItem local,
  required NoteItem remote,
  required bool remoteNewer,
}) {
  if (contentEqual(local, remote)) {
    return remoteNewer ? remote : local;
  }
  if (base == null) {
    return remoteNewer ? remote : local;
  }
  if (contentEqual(local, base)) return remote;
  if (contentEqual(remote, base)) return local;
  // Both sides moved to the same fingerprint (handled by contentEqual above)
  // or no conflict was declared — prefer remote as canonical content.
  return remote;
}

NoteItem _buildMergedNote({
  required NoteItem? base,
  required NoteItem local,
  required NoteItem remote,
}) {
  final remoteNewer = !local.updatedAt.isAfter(remote.updatedAt);
  final content = _contentSource(
    base: base,
    local: local,
    remote: remote,
    remoteNewer: remoteNewer,
  );

  final checklistItems = _mergeChecklistItems(
    base: base?.checklistItems ?? const [],
    local: local.checklistItems,
    remote: remote.checklistItems,
    structure: content.checklistItems,
    remoteNewer: remoteNewer,
  );

  final completed = _pickBool(
    base: base?.completed,
    local: local.completed,
    remote: remote.completed,
    remoteNewer: remoteNewer,
  );
  final pinned = _pickBool(
    base: base?.pinned,
    local: local.pinned,
    remote: remote.pinned,
    remoteNewer: remoteNewer,
  );
  final dueHasTime = _pickBool(
    base: base?.dueHasTime,
    local: local.dueHasTime,
    remote: remote.dueHasTime,
    remoteNewer: remoteNewer,
  );
  final completedAt = _pickNullableDate(
    base: base?.completedAt,
    local: local.completedAt,
    remote: remote.completedAt,
    remoteNewer: remoteNewer,
  );
  final dueAt = _pickNullableDate(
    base: base?.dueAt,
    local: local.dueAt,
    remote: remote.dueAt,
    remoteNewer: remoteNewer,
  );
  final todayAt = _pickNullableDate(
    base: base?.todayAt,
    local: local.todayAt,
    remote: remote.todayAt,
    remoteNewer: remoteNewer,
  );
  final archivedAt = _pickNullableDate(
    base: base?.archivedAt,
    local: local.archivedAt,
    remote: remote.archivedAt,
    remoteNewer: remoteNewer,
  );
  final reminder = _pickNullableInt(
    base: base?.reminderMinutesBefore,
    local: local.reminderMinutesBefore,
    remote: remote.reminderMinutesBefore,
    remoteNewer: remoteNewer,
  );
  final cover = _pickNullableString(
    base: base?.coverAttachmentId,
    local: local.coverAttachmentId,
    remote: remote.coverAttachmentId,
    remoteNewer: remoteNewer,
  );
  final tags = _pickStringList(
    base: base?.tags,
    local: local.tags,
    remote: remote.tags,
    remoteNewer: remoteNewer,
  );

  final updatedAt = local.updatedAt.isAfter(remote.updatedAt)
      ? local.updatedAt
      : remote.updatedAt;

  return local.copyWith(
    type: content.type,
    title: content.title,
    body: content.body,
    pinned: pinned,
    completed: completed,
    tags: tags,
    dueAt: dueAt,
    dueHasTime: dueHasTime,
    todayAt: todayAt,
    completedAt: completedAt,
    archivedAt: archivedAt,
    reminderMinutesBefore: reminder,
    coverAttachmentId: cover,
    checklistTitle: content.checklistTitle,
    checklistItems: checklistItems,
    updatedAt: updatedAt,
    syncConflictOfNoteId: null,
  );
}

bool _pickBool({
  required bool? base,
  required bool local,
  required bool remote,
  required bool remoteNewer,
}) {
  if (base == null) return remoteNewer ? remote : local;
  final localChanged = local != base;
  final remoteChanged = remote != base;
  if (localChanged && !remoteChanged) return local;
  if (remoteChanged && !localChanged) return remote;
  if (localChanged && remoteChanged && local != remote) {
    return remoteNewer ? remote : local;
  }
  return remote;
}

DateTime? _pickNullableDate({
  required DateTime? base,
  required DateTime? local,
  required DateTime? remote,
  required bool remoteNewer,
}) {
  return _pickByEquality<DateTime?>(
    base: base,
    local: local,
    remote: remote,
    remoteNewer: remoteNewer,
    equal: (a, b) => a == b,
  );
}

int? _pickNullableInt({
  required int? base,
  required int? local,
  required int? remote,
  required bool remoteNewer,
}) {
  return _pickByEquality<int?>(
    base: base,
    local: local,
    remote: remote,
    remoteNewer: remoteNewer,
    equal: (a, b) => a == b,
  );
}

String? _pickNullableString({
  required String? base,
  required String? local,
  required String? remote,
  required bool remoteNewer,
}) {
  return _pickByEquality<String?>(
    base: base,
    local: local,
    remote: remote,
    remoteNewer: remoteNewer,
    equal: (a, b) => a == b,
  );
}

List<String> _pickStringList({
  required List<String>? base,
  required List<String> local,
  required List<String> remote,
  required bool remoteNewer,
}) {
  bool listEq(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    final as = [...a]..sort();
    final bs = [...b]..sort();
    for (var i = 0; i < as.length; i++) {
      if (as[i] != bs[i]) return false;
    }
    return true;
  }

  return _pickByEquality<List<String>>(
    base: base,
    local: local,
    remote: remote,
    remoteNewer: remoteNewer,
    equal: listEq,
  );
}

T _pickByEquality<T>({
  required T? base,
  required T local,
  required T remote,
  required bool remoteNewer,
  required bool Function(T? a, T? b) equal,
}) {
  if (base == null) return remoteNewer ? remote : local;
  final localChanged = !equal(local, base);
  final remoteChanged = !equal(remote, base);
  if (localChanged && !remoteChanged) return local;
  if (remoteChanged && !localChanged) return remote;
  if (localChanged && remoteChanged && !equal(local, remote)) {
    return remoteNewer ? remote : local;
  }
  return remote;
}

List<ChecklistItem> _mergeChecklistItems({
  required List<ChecklistItem> base,
  required List<ChecklistItem> local,
  required List<ChecklistItem> remote,
  required List<ChecklistItem> structure,
  required bool remoteNewer,
}) {
  final baseCompleted = {for (final i in base) i.id: i.completed};
  final localCompleted = {for (final i in local) i.id: i.completed};
  final remoteCompleted = {for (final i in remote) i.id: i.completed};

  return [
    for (final item in structure)
      item.copyWith(
        completed: _pickBool(
          base: baseCompleted.containsKey(item.id)
              ? baseCompleted[item.id]
              : null,
          local: localCompleted[item.id] ?? item.completed,
          remote: remoteCompleted[item.id] ?? item.completed,
          remoteNewer: remoteNewer,
        ),
      ),
  ];
}

List<ChecklistItem> _sortedChecklist(List<ChecklistItem> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.id.compareTo(b.id);
    });
  return sorted;
}

bool _sameNoteIgnoringUpdatedAt(NoteItem a, NoteItem b) {
  return contentEqual(a, b) && mergeableStateEqual(a, b) && a.type == b.type;
}
