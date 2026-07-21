import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/date_only.dart';
import '../domain/day_entry.dart';
import '../domain/day_log.dart';
import '../domain/day_migration.dart';
import '../domain/note_item.dart';
import '../domain/task_dates.dart';
import 'day_entries_repository.dart';
import 'task_reminders_service.dart';

class NotesRepository {
  NotesRepository._();

  static final NotesRepository instance = NotesRepository._();

  static const String _boxName = 'notes';
  static const _uuid = Uuid();

  late Box<Map> _box;
  TaskRemindersService _reminders = TaskRemindersService.instance;
  DayEntriesRepository _dayEntries = DayEntriesRepository.instance;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// For tests: inject an already-opened box.
  @visibleForTesting
  Future<void> initWithBox(Box<Map> box) async {
    _box = box;
  }

  @visibleForTesting
  set remindersForTests(TaskRemindersService service) {
    _reminders = service;
  }

  @visibleForTesting
  set dayEntriesForTests(DayEntriesRepository repo) {
    _dayEntries = repo;
  }

  ValueListenable<Box<Map>> listenable() => _box.listenable();

  List<NoteItem> _readAllRaw() {
    return _box.values
        .map((raw) => NoteItem.fromMap(Map<dynamic, dynamic>.from(raw)))
        .toList();
  }

  /// Active (non-archived) items, sorted by [updatedAt] desc.
  List<NoteItem> getAll() {
    final items = _readAllRaw().where((item) => !item.isArchived).toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  /// Archived items sorted by [archivedAt] desc.
  List<NoteItem> getArchived() {
    final items = _readAllRaw().where((item) => item.isArchived).toList();
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
  }

  Future<void> update(NoteItem item) async {
    await _box.put(item.id, item.toMap());
    await _syncReminder(item);
  }

  Future<void> delete(String id) async {
    await _cancelReminder(id);
    await _box.delete(id);
  }

  Future<void> togglePinned(String id) async {
    final current = getById(id);
    if (current == null) return;
    await update(
      current.copyWith(
        pinned: !current.pinned,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleCompleted(String id) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;
    final now = DateTime.now();
    final nextCompleted = !current.completed;
    final day = commitmentDayFor(current, now);
    await update(
      current.copyWith(
        completed: nextCompleted,
        completedAt: nextCompleted ? now : null,
        updatedAt: now,
      ),
    );
    await _syncDayEntry(() async {
      if (nextCompleted) {
        await _dayEntries.markCompleted(
          noteId: id,
          day: day,
          outcomeAt: now,
        );
      } else {
        await _dayEntries.reopen(noteId: id, day: day);
      }
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
        reminderMinutesBefore:
            on ? null : current.reminderMinutesBefore,
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
        reminderMinutesBefore:
            dueAt != null ? reminderMinutesBefore : null,
        updatedAt: now,
      ),
    );
    await _syncDayEntry(() async {
      if (todayOn && nextTodayAt != null) {
        await _dayEntries.ensurePlanned(
          noteId: id,
          day: dateOnly(nextTodayAt),
          via: DayVia.todaySwitch,
          now: now,
        );
      } else if (!todayOn && previousToday != null) {
        await _dayEntries.markBackloggedIfOpen(
          noteId: id,
          day: dateOnly(previousToday),
          outcomeAt: now,
        );
      }
      if (dueAt != null && !todayOn) {
        await _dayEntries.ensurePlanned(
          noteId: id,
          day: dateOnly(dueAt),
          via: DayVia.due,
          now: now,
        );
      }
    }, 'applyTaskWhen');
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

  /// Copies content/tags/dates; resets pin, completion and archive. Returns the copy.
  Future<NoteItem?> duplicate(String id) async {
    final current = getById(id);
    if (current == null) return null;
    final now = DateTime.now();
    final copy = current.copyWith(
      id: _uuid.v4(),
      pinned: false,
      completed: false,
      completedAt: null,
      archivedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    await add(copy);
    return copy;
  }

  Future<void> archive(String id) async {
    final current = getById(id);
    if (current == null || current.isArchived) return;
    final now = DateTime.now();
    await update(
      current.copyWith(
        archivedAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> restore(String id) async {
    final current = getById(id);
    if (current == null || !current.isArchived) return;
    await update(
      current.copyWith(
        archivedAt: null,
        updatedAt: DateTime.now(),
      ),
    );
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
      final next =
          item.tags.where((t) => t.toLowerCase() != key).toList(growable: false);
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
