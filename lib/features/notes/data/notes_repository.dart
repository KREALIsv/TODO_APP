import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_repo_notifier.dart';
import '../../../core/storage/local_storage_service.dart';
import '../domain/date_only.dart';
import '../domain/day_entry.dart';
import '../domain/day_log.dart';
import '../domain/day_migration.dart';
import '../domain/note_item.dart';
import '../domain/task_dates.dart';
import '../../sync/domain/sync_conflict.dart';
import 'attachments_repository.dart';
import 'day_entries_repository.dart';
import 'task_reminders_service.dart';

class NotesRepository {
  NotesRepository._();

  static final NotesRepository instance = NotesRepository._();

  static const String _boxName = 'notes';
  static const _uuid = Uuid();

  late Box<Map> _box;
  final _changes = HiveRepoNotifier();
  TaskRemindersService _reminders = TaskRemindersService.instance;
  DayEntriesRepository _dayEntries = DayEntriesRepository.instance;
  AttachmentsRepository _attachments = AttachmentsRepository.instance;

  Future<void> init() async {
    _box = await LocalStorageService.instance.openBox<Map>(_boxName);
    _changes.bind(_box.listenable());
  }

  /// Re-read Hive after another tab on the same origin wrote to storage (web).
  Future<void> reloadFromPeerTab() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    _box = await LocalStorageService.instance.reopenBox<Map>(_boxName);
    _changes.bind(_box.listenable());
    _changes.reloadComplete();
  }

  Listenable get changes => _changes;

  /// For tests: inject an already-opened box.
  @visibleForTesting
  Future<void> initWithBox(Box<Map> box) async {
    _box = box;
    _changes.bind(_box.listenable());
  }

  @visibleForTesting
  set remindersForTests(TaskRemindersService service) {
    _reminders = service;
  }

  @visibleForTesting
  set dayEntriesForTests(DayEntriesRepository repo) {
    _dayEntries = repo;
  }

  @visibleForTesting
  set attachmentsForTests(AttachmentsRepository repo) {
    _attachments = repo;
  }

  ValueListenable<Box<Map>> listenable() => _box.listenable();

  List<NoteItem> _readAllRaw() {
    return _box.values
        .map((raw) => NoteItem.fromMap(Map<dynamic, dynamic>.from(raw)))
        .toList();
  }

  /// Active (non-archived) items, sorted by [updatedAt] desc.
  List<NoteItem> getAll() {
    final items = _readAllRaw()
        .where((item) => !item.isArchived && !isSyncConflictCopy(item))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  /// Archived items sorted by [archivedAt] desc.
  List<NoteItem> getArchived() {
    final items = _readAllRaw()
        .where((item) => item.isArchived && !isSyncConflictCopy(item))
        .toList();
    items.sort((a, b) {
      final aAt = a.archivedAt ?? a.updatedAt;
      final bAt = b.archivedAt ?? b.updatedAt;
      return bAt.compareTo(aAt);
    });
    return items;
  }

  NoteItem? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return NoteItem.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  /// Notes created automatically when sync could not merge two versions.
  List<NoteItem> getSyncConflictCopies() {
    return _readAllRaw()
        .where(isSyncConflictCopy)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  int get pendingSyncConflictCount => getSyncConflictCopies().length;

  List<SyncConflictPair> getPendingSyncConflicts() {
    return getSyncConflictCopies()
        .map(
          (copy) => SyncConflictPair(
            copy: copy,
            canonical: copy.syncConflictOfNoteId == null
                ? null
                : getById(copy.syncConflictOfNoteId!),
          ),
        )
        .toList(growable: false);
  }

  /// Keeps the canonical (cloud) version and removes the local snapshot copy.
  Future<void> resolveSyncConflictKeepRemote(String conflictCopyId) async {
    final copy = getById(conflictCopyId);
    if (copy == null || !isSyncConflictCopy(copy)) return;
    await delete(conflictCopyId);
  }

  /// Replaces the canonical note with the local snapshot and removes the copy.
  Future<void> resolveSyncConflictKeepLocal(String conflictCopyId) async {
    final copy = getById(conflictCopyId);
    if (copy == null || !isSyncConflictCopy(copy)) return;

    final canonicalId = copy.syncConflictOfNoteId;
    if (canonicalId == null) {
      await _promoteConflictCopyToStandalone(copy);
      return;
    }

    final canonical = getById(canonicalId);
    if (canonical == null) {
      await _promoteConflictCopyToStandalone(copy);
      return;
    }

    await update(
      mergeConflictLocalOntoCanonical(
        canonical: canonical,
        localSnapshot: copy,
        now: DateTime.now(),
      ),
    );
    await delete(conflictCopyId);
  }

  /// Turns the conflict copy into a regular standalone note.
  Future<void> resolveSyncConflictKeepBoth(String conflictCopyId) async {
    final copy = getById(conflictCopyId);
    if (copy == null || !isSyncConflictCopy(copy)) return;
    await _promoteConflictCopyToStandalone(copy);
  }

  Future<void> _promoteConflictCopyToStandalone(NoteItem copy) async {
    await update(
      clearSyncConflictMetadata(copy).copyWith(updatedAt: DateTime.now()),
    );
  }

  /// Deletes all sync conflict copies. Returns how many were removed.
  Future<int> deleteSyncConflictCopies() async {
    final conflicts = getSyncConflictCopies();
    for (final item in conflicts) {
      await delete(item.id);
    }
    return conflicts.length;
  }

  Future<void> _syncReminder(NoteItem item) async {
    try {
      await _reminders.sync(item);
    } catch (e, st) {
      debugPrint('Reminder sync failed for ${item.id}: $e\n$st');
    }
  }

  Future<void> _cancelReminder(String id) async {
    try {
      await _reminders.cancel(id);
    } catch (e, st) {
      debugPrint('Reminder cancel failed for $id: $e\n$st');
    }
  }

  /// Re-schedule all active task reminders (e.g. after app start / reboot).
  Future<void> syncAllReminders() async {
    try {
      await _reminders.syncAll(getAll());
    } catch (e, st) {
      debugPrint('Reminder syncAll failed: $e\n$st');
    }
  }

  Future<void> add(NoteItem item) async {
    await _box.put(item.id, item.toMap());
    await _syncReminder(item);
    if (item.type != NoteType.task) return;

    final now = DateTime.now();
    await _syncDayEntry(() async {
      if (item.isTodayCommitment(now) && item.todayAt != null) {
        await _dayEntries.ensurePlanned(
          noteId: item.id,
          day: dateOnly(item.todayAt!),
          via: DayVia.todaySwitch,
          now: now,
        );
      } else if (item.dueAt != null) {
        await _dayEntries.ensurePlanned(
          noteId: item.id,
          day: dateOnly(item.dueAt!),
          via: DayVia.due,
          now: now,
        );
      }
    }, 'add');
  }

  Future<void> update(NoteItem item) async {
    await _box.put(item.id, item.toMap());
    await _syncReminder(item);
  }

  /// Persists a task edited in [NoteEditorScreen] and mirrors day-entry writers
  /// used by Migrar/Agendar/applyTaskWhen.
  Future<void> saveTaskFromEditor({
    required NoteItem previous,
    required NoteItem next,
  }) async {
    if (next.type != NoteType.task) {
      await update(next);
      return;
    }

    final now = DateTime.now();
    await update(next);

    await _syncDayEntry(() async {
      if (_taskWhenFieldsDiffer(previous, next, now)) {
        await _syncWhenDayEntries(
          noteId: next.id,
          previous: previous,
          todayOn: next.isTodayCommitment(now),
          dueAt: next.dueAt,
          now: now,
        );
      }

      if (previous.completed != next.completed) {
        if (next.completed) {
          final day = next.completedAt != null
              ? dateOnly(next.completedAt!)
              : commitmentDayFor(next, now);
          final outcomeAt = completionOutcomeAt(day, next.completedAt ?? now);
          await _dayEntries.markCompleted(
            noteId: next.id,
            day: day,
            outcomeAt: outcomeAt,
          );
        } else {
          final reopenDay = previous.completedAt != null
              ? dateOnly(previous.completedAt!)
              : commitmentDayFor(previous, now);
          await _dayEntries.reopen(noteId: next.id, day: reopenDay);
        }
      }
    }, 'saveTaskFromEditor');
  }

  Future<void> saveFromSync(NoteItem item) async {
    await _box.put(item.id, item.toMap());
    await _syncReminder(item);
  }

  Future<void> delete(String id) async {
    await _cancelReminder(id);
    try {
      await _attachments.deleteForNote(id);
    } catch (e, st) {
      debugPrint('Attachment cleanup failed for $id: $e\n$st');
    }
    await _box.delete(id);
  }

  Future<void> togglePinned(String id) async {
    final current = getById(id);
    if (current == null) return;
    await update(
      current.copyWith(pinned: !current.pinned, updatedAt: DateTime.now()),
    );
  }

  Future<void> toggleCompleted(String id, {DateTime? onDay}) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;
    final now = DateTime.now();
    final nextCompleted = !current.completed;
    if (nextCompleted) {
      final day = commitmentDayFor(current, now, onDay: onDay);
      final outcomeAt = completionOutcomeAt(day, now);
      await update(
        current.copyWith(
          completed: true,
          completedAt: outcomeAt,
          updatedAt: now,
        ),
      );
      await _syncDayEntry(() async {
        await _dayEntries.markCompleted(
          noteId: id,
          day: day,
          outcomeAt: outcomeAt,
        );
      }, 'toggleCompleted');
      return;
    }

    final reopenDay = current.completedAt != null
        ? dateOnly(current.completedAt!)
        : commitmentDayFor(current, now, onDay: onDay);
    await update(
      current.copyWith(
        completed: false,
        completedAt: null,
        updatedAt: now,
      ),
    );
    await _syncDayEntry(() async {
      await _dayEntries.reopen(noteId: id, day: reopenDay);
    }, 'toggleCompleted');
  }

  Future<void> setTodayCommitment(String id, bool on) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;
    final now = DateTime.now();
    final previousToday = current.todayAt;
    // Match editor «Hoy» exclusivity: commitment clears due / reminder.
    await update(
      current.copyWith(
        todayAt: on ? now : null,
        dueAt: on ? null : current.dueAt,
        dueHasTime: on ? false : current.dueHasTime,
        reminderMinutesBefore: on ? null : current.reminderMinutesBefore,
        updatedAt: now,
      ),
    );
    await _syncDayEntry(() async {
      if (on) {
        await _dayEntries.ensurePlanned(
          noteId: id,
          day: dateOnly(now),
          via: DayVia.todaySwitch,
          now: now,
        );
      } else if (previousToday != null) {
        await _dayEntries.markBackloggedIfOpen(
          noteId: id,
          day: dateOnly(previousToday),
          outcomeAt: now,
        );
      }
    }, 'setTodayCommitment');
  }

  /// Applies exclusive «¿Cuándo?» fields (same contract as [TaskWhenField.onChanged]).
  Future<void> applyTaskWhen(
    String id, {
    required bool todayOn,
    DateTime? dueAt,
    bool dueHasTime = false,
    int? reminderMinutesBefore,
  }) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;
    final now = DateTime.now();
    final previousToday = current.todayAt;
    final nextTodayAt = todayOn
        ? (current.isTodayCommitment(now) ? current.todayAt : now)
        : null;
    await update(
      current.copyWith(
        todayAt: nextTodayAt,
        dueAt: dueAt,
        dueHasTime: dueHasTime,
        reminderMinutesBefore: dueAt != null ? reminderMinutesBefore : null,
        updatedAt: now,
      ),
    );
    await _syncDayEntry(
      () => _syncWhenDayEntries(
        noteId: id,
        previous: current,
        todayOn: todayOn,
        dueAt: dueAt,
        now: now,
      ),
      'applyTaskWhen',
    );
  }

  bool _taskWhenFieldsDiffer(NoteItem previous, NoteItem next, DateTime now) {
    if (previous.isTodayCommitment(now) != next.isTodayCommitment(now)) {
      return true;
    }
    final prevDue = previous.dueAt != null ? dateOnly(previous.dueAt!) : null;
    final nextDue = next.dueAt != null ? dateOnly(next.dueAt!) : null;
    return prevDue != nextDue;
  }

  Future<void> _syncWhenDayEntries({
    required String noteId,
    required NoteItem previous,
    required bool todayOn,
    required DateTime? dueAt,
    required DateTime now,
  }) async {
    final previousToday = previous.todayAt;
    final nextTodayAt = todayOn
        ? (previous.isTodayCommitment(now) ? previous.todayAt : now)
        : null;
    final previousDue =
        previous.dueAt != null ? dateOnly(previous.dueAt!) : null;
    final nextDue = dueAt != null ? dateOnly(dueAt) : null;
    final previousTodayDay =
        previousToday != null ? dateOnly(previousToday) : null;

    if (todayOn && nextTodayAt != null) {
      final todayDay = dateOnly(nextTodayAt);
      if (previousDue != null && previousDue != todayDay) {
        await _dayEntries.applyMigrationPatches(
          noteId: noteId,
          patches: migrateTo(previous, previousDue, todayDay, now),
          now: now,
        );
        return;
      }
      if (previousTodayDay != null && previousTodayDay != todayDay) {
        await _dayEntries.applyMigrationPatches(
          noteId: noteId,
          patches: migrateTo(previous, previousTodayDay, todayDay, now),
          now: now,
        );
        return;
      }
      await _dayEntries.ensurePlanned(
        noteId: noteId,
        day: todayDay,
        via: DayVia.todaySwitch,
        now: now,
      );
      return;
    }

    if (!todayOn &&
        previousDue != null &&
        nextDue != null &&
        previousDue != nextDue) {
      await _dayEntries.applyMigrationPatches(
        noteId: noteId,
        patches: scheduleTo(previous, previousDue, nextDue, now),
        now: now,
      );
      return;
    }

    if (!todayOn &&
        previousTodayDay != null &&
        nextDue != null &&
        previousTodayDay != nextDue) {
      await _dayEntries.applyMigrationPatches(
        noteId: noteId,
        patches: scheduleTo(previous, previousTodayDay, nextDue, now),
        now: now,
      );
      return;
    }

    if (!todayOn && previousTodayDay != null) {
      await _dayEntries.markBackloggedIfOpen(
        noteId: noteId,
        day: previousTodayDay,
        outcomeAt: now,
      );
    }

    if (!todayOn && previousDue != null && nextDue == null) {
      await _dayEntries.markBackloggedIfOpen(
        noteId: noteId,
        day: previousDue,
        outcomeAt: now,
      );
    }

    if (!todayOn && nextDue != null) {
      await _dayEntries.ensurePlanned(
        noteId: noteId,
        day: nextDue,
        via: DayVia.due,
        now: now,
      );
    }
  }

  /// Moves a task's commitment from [fromDay] to [toDay].
  Future<void> migrateTaskToDay(
    String id,
    DateTime toDay, {
    DateTime? fromDay,
  }) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;

    final now = DateTime.now();
    final originDay = dateOnly(fromDay ?? commitmentDayFor(current, now));
    final targetDay = dateOnly(toDay);
    final patches = migrateTo(current, originDay, targetDay, now);
    await update(patches.noteUpdate.copyWith(reminderMinutesBefore: null));
    await _syncDayEntry(
      () => _dayEntries.applyMigrationPatches(
        noteId: id,
        patches: patches,
        now: now,
      ),
      'migrateTaskToDay',
    );
  }

  /// Schedules a task on [toDay], retaining any reminder for its new due date.
  Future<void> scheduleTaskToDay(
    String id,
    DateTime toDay, {
    DateTime? fromDay,
  }) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;

    final now = DateTime.now();
    final originDay = dateOnly(fromDay ?? commitmentDayFor(current, now));
    final targetDay = dateOnly(toDay);
    final patches = scheduleTo(current, originDay, targetDay, now);
    await update(patches.noteUpdate);
    await _syncDayEntry(
      () => _dayEntries.applyMigrationPatches(
        noteId: id,
        patches: patches,
        now: now,
      ),
      'scheduleTaskToDay',
    );
  }

  /// Returns a task to the backlog and closes its day's open entry.
  Future<void> sendTaskToBacklog(String id, {DateTime? fromDay}) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;

    final now = DateTime.now();
    final originDay = dateOnly(fromDay ?? commitmentDayFor(current, now));
    final patches = sendToBacklog(current, originDay, now);
    await update(patches.noteUpdate);
    await _syncDayEntry(
      () => _dayEntries.applyMigrationPatches(
        noteId: id,
        patches: patches,
        now: now,
      ),
      'sendTaskToBacklog',
    );
  }

  /// Cancels a task's commitment on [fromDay] without deleting the task.
  Future<void> cancelTaskOnDay(String id, {DateTime? fromDay}) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;

    final now = DateTime.now();
    final originDay = dateOnly(fromDay ?? commitmentDayFor(current, now));
    final patches = cancelOnDay(current, originDay, now);
    await update(patches.noteUpdate);
    await _syncDayEntry(
      () => _dayEntries.applyMigrationPatches(
        noteId: id,
        patches: patches,
        now: now,
      ),
      'cancelTaskOnDay',
    );
  }

  Future<void> _syncDayEntry(
    Future<void> Function() action,
    String contextLabel,
  ) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('DayEntry sync failed on $contextLabel: $e\n$st');
    }
  }

  /// Copies content/tags/dates/attachments; resets pin, completion and archive.
  Future<NoteItem?> duplicate(String id) async {
    final current = getById(id);
    if (current == null) return null;
    final now = DateTime.now();
    final newId = _uuid.v4();
    String? newCoverId;

    for (final attachment in _attachments.forNote(id)) {
      final bytes = _attachments.bytesFor(attachment.id);
      if (bytes == null) continue;
      final created = await _attachments.addImage(
        noteId: newId,
        bytes: bytes,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
      );
      if (attachment.id == current.coverAttachmentId) {
        newCoverId = created.id;
      }
    }

    final copy = current.copyWith(
      id: newId,
      pinned: false,
      completed: false,
      completedAt: null,
      archivedAt: null,
      createdAt: now,
      updatedAt: now,
      coverAttachmentId: newCoverId,
      checklistItems: current.checklistItems
          .map((item) => item.copyWith(id: _uuid.v4()))
          .toList(),
    );
    await add(copy);
    return copy;
  }

  Future<void> archive(String id) async {
    final current = getById(id);
    if (current == null || current.isArchived) return;
    final now = DateTime.now();
    await update(current.copyWith(archivedAt: now, updatedAt: now));
  }

  Future<void> restore(String id) async {
    final current = getById(id);
    if (current == null || !current.isArchived) return;
    await update(current.copyWith(archivedAt: null, updatedAt: DateTime.now()));
  }

  /// Unique tags across active notes, for autocomplete.
  Set<String> getAllTags() {
    final tags = <String>{};
    for (final item in getAll()) {
      tags.addAll(item.tags);
    }
    return tags;
  }

  /// Renombra una etiqueta en todas las notas (activas y archivadas).
  Future<void> renameTag(String from, String to) async {
    final oldKey = from.trim().toLowerCase();
    final newName = to.trim();
    if (oldKey.isEmpty || newName.isEmpty) return;

    for (final item in _readAllRaw()) {
      var changed = false;
      final next = <String>[];
      for (final tag in item.tags) {
        if (tag.toLowerCase() == oldKey) {
          if (!next.any((t) => t.toLowerCase() == newName.toLowerCase())) {
            next.add(newName);
          }
          changed = true;
        } else {
          next.add(tag);
        }
      }
      if (changed) {
        await update(item.copyWith(tags: next, updatedAt: DateTime.now()));
      }
    }
  }

  /// Quita una etiqueta de todas las notas (activas y archivadas).
  Future<void> removeTag(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;

    for (final item in _readAllRaw()) {
      if (!item.tags.any((t) => t.toLowerCase() == key)) continue;
      final next = item.tags
          .where((t) => t.toLowerCase() != key)
          .toList(growable: false);
      await update(item.copyWith(tags: next, updatedAt: DateTime.now()));
    }
  }

  /// All notes (active + archived) as serializable maps for backup.
  List<Map<String, dynamic>> exportAllMaps() {
    return _readAllRaw().map((item) => item.toMap()).toList(growable: false);
  }

  /// Replaces all notes with [maps]. Invalid maps throw via [NoteItem.fromMap].
  Future<void> replaceAllFromMaps(List<Map<String, dynamic>> maps) async {
    await _box.clear();
    for (final map in maps) {
      final item = NoteItem.fromMap(map);
      await _box.put(item.id, item.toMap());
    }
  }

  /// Production wipe used by Settings. Separate from test-only [clear].
  Future<void> resetAll() async {
    await _box.clear();
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box.clear();
  }
}
