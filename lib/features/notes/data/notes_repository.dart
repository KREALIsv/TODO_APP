import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/note_item.dart';
import '../domain/task_dates.dart';
import 'task_reminders_service.dart';

class NotesRepository {
  NotesRepository._();

  static final NotesRepository instance = NotesRepository._();

  static const String _boxName = 'notes';

  late Box<Map> _box;
  TaskRemindersService _reminders = TaskRemindersService.instance;

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
    await update(
      current.copyWith(
        completed: nextCompleted,
        completedAt: nextCompleted ? now : null,
        updatedAt: now,
      ),
    );
  }

  Future<void> setTodayCommitment(String id, bool on) async {
    final current = getById(id);
    if (current == null || current.type != NoteType.task) return;
    final now = DateTime.now();
    await update(
      current.copyWith(
        todayAt: on ? now : null,
        updatedAt: now,
      ),
    );
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
