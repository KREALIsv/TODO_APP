import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/date_only.dart';
import '../domain/day_entry.dart';
import '../domain/day_log.dart' as day_log;
import '../domain/day_migration.dart';
import '../domain/note_item.dart';

class DayEntriesRepository {
  DayEntriesRepository._();

  static final DayEntriesRepository instance = DayEntriesRepository._();

  static const String _boxName = 'day_entries';
  static const _uuid = Uuid();

  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// For tests: inject an already-opened box.
  @visibleForTesting
  Future<void> initWithBox(Box<Map> box) async {
    _box = box;
  }

  ValueListenable<Box<Map>> listenable() => _box.listenable();

  List<DayEntry> getAll() {
    return _box.values
        .map((raw) => DayEntry.fromMap(Map<dynamic, dynamic>.from(raw)))
        .toList(growable: false);
  }

  DayEntry? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return DayEntry.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  /// Existing entry for (noteId, day), if any.
  DayEntry? findForNoteDay(String noteId, DateTime day) {
    final key = dateOnly(day);
    for (final entry in getAll()) {
      if (entry.noteId == noteId && dateOnly(entry.day) == key) {
        return entry;
      }
    }
    return null;
  }

  List<DayEntry> entriesForDay(DateTime day) =>
      day_log.entriesForDay(getAll(), day);

  /// Open pending rows for [day].
  List<DayEntry> openPendingForDay(DateTime day) {
    return entriesForDay(day)
        .where((e) => e.outcome == DayOutcome.open)
        .toList(growable: false);
  }

  /// Upsert by (noteId, day): updates existing or inserts [entry].
  Future<DayEntry> upsert(DayEntry entry) async {
    final existing = findForNoteDay(entry.noteId, entry.day);
    final toSave = existing == null
        ? entry.copyWith(day: dateOnly(entry.day))
        : entry.copyWith(
            id: existing.id,
            day: dateOnly(entry.day),
            createdAt: existing.createdAt,
          );
    await _box.put(toSave.id, toSave.toMap());
    return toSave;
  }

  /// Idempotent: ensure an open planned entry exists for (note, day).
  Future<DayEntry> ensurePlanned({
    required String noteId,
    required DateTime day,
    required DayVia via,
    DateTime? now,
  }) async {
    final existing = findForNoteDay(noteId, day);
    if (existing != null) {
      return existing;
    }
    final created = now ?? DateTime.now();
    return upsert(
      DayEntry(
        id: _uuid.v4(),
        noteId: noteId,
        day: dateOnly(day),
        via: via,
        outcome: DayOutcome.open,
        createdAt: created,
      ),
    );
  }

  /// Mark entry for (note, day) as completed (or create if missing).
  Future<DayEntry> markCompleted({
    required String noteId,
    required DateTime day,
    required DateTime outcomeAt,
    DayVia via = DayVia.manual,
  }) async {
    final existing = findForNoteDay(noteId, day);
    if (existing != null) {
      return upsert(
        existing.copyWith(
          outcome: DayOutcome.completed,
          outcomeAt: outcomeAt,
          targetDay: null,
        ),
      );
    }
    return upsert(
      DayEntry(
        id: _uuid.v4(),
        noteId: noteId,
        day: dateOnly(day),
        via: via,
        outcome: DayOutcome.completed,
        outcomeAt: outcomeAt,
        createdAt: outcomeAt,
      ),
    );
  }

  /// Re-open a completed entry (undo complete).
  Future<DayEntry?> reopen({
    required String noteId,
    required DateTime day,
  }) async {
    final existing = findForNoteDay(noteId, day);
    if (existing == null) return null;
    return upsert(
      existing.copyWith(
        outcome: DayOutcome.open,
        outcomeAt: null,
        targetDay: null,
      ),
    );
  }

  /// When clearing Hoy commitment: close open entry as backlogged.
  Future<void> markBackloggedIfOpen({
    required String noteId,
    required DateTime day,
    required DateTime outcomeAt,
  }) async {
    final existing = findForNoteDay(noteId, day);
    if (existing == null || existing.outcome != DayOutcome.open) return;
    await upsert(
      existing.copyWith(
        outcome: DayOutcome.backlogged,
        outcomeAt: outcomeAt,
        targetDay: null,
      ),
    );
  }

  Future<void> _applyOriginPatch({
    required String noteId,
    required DayOriginPatch patch,
    required DateTime now,
  }) async {
    final existing = findForNoteDay(noteId, patch.day);
    final entry = existing == null
        ? DayEntry(
            id: _uuid.v4(),
            noteId: noteId,
            day: patch.day,
            via: DayVia.manual,
            outcome: patch.outcome,
            targetDay: patch.targetDay,
            outcomeAt: patch.outcomeAt,
            createdAt: now,
          )
        : existing.copyWith(
            outcome: patch.outcome,
            targetDay: patch.targetDay,
            outcomeAt: patch.outcomeAt,
          );
    await upsert(entry);
  }

  Future<void> _ensureOpenDestination({
    required String noteId,
    required DateTime day,
    required DayVia via,
    required DateTime now,
  }) async {
    final existing = findForNoteDay(noteId, day);
    if (existing == null) {
      await ensurePlanned(noteId: noteId, day: day, via: via, now: now);
      return;
    }
    await upsert(
      existing.copyWith(
        via: via,
        outcome: DayOutcome.open,
        targetDay: null,
        outcomeAt: null,
      ),
    );
  }

  /// Persists coordinated day-entry changes from [DayMigrationPatches].
  Future<void> applyMigrationPatches({
    required String noteId,
    required DayMigrationPatches patches,
    required DateTime now,
  }) async {
    await _applyOriginPatch(
      noteId: noteId,
      now: now,
      patch: patches.originUpdate,
    );
    final destination = patches.destinationEnsure;
    if (destination != null) {
      await _ensureOpenDestination(
        noteId: noteId,
        day: destination.day,
        via: destination.via,
        now: now,
      );
    }
  }

  /// Lazy backfill for a past day with no entries yet.
  ///
  /// Documented limitation: pre-slice history may be incomplete.
  Future<List<DayEntry>> backfillDayIfEmpty({
    required DateTime day,
    required List<NoteItem> notes,
  }) async {
    final existing = entriesForDay(day);
    if (existing.isNotEmpty) return existing;

    final synthesized = day_log.synthesizeEntriesFromNotes(
      notes: notes,
      day: day,
      newId: _uuid.v4,
    );
    for (final entry in synthesized) {
      await upsert(entry);
    }
    return entriesForDay(day);
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box.clear();
  }
}
