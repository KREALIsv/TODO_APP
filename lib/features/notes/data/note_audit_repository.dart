import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_repo_notifier.dart';
import '../domain/note_audit_diff.dart';
import '../domain/note_audit_event.dart';
import '../domain/note_item.dart';

class NoteAuditRepository {
  NoteAuditRepository._();

  static final NoteAuditRepository instance = NoteAuditRepository._();

  static const String boxName = 'note_audits';
  static const _uuid = Uuid();

  late Box<Map> _box;
  final _changes = HiveRepoNotifier();
  var _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(boxName);
    _changes.bind(_box.listenable());
    _ready = true;
  }

  Future<void> reloadFromPeerTab() async {
    if (!Hive.isBoxOpen(boxName)) return;
    await _box.close();
    _box = await Hive.openBox<Map>(boxName);
    _changes.bind(_box.listenable());
    _changes.reloadComplete();
  }

  Listenable get changes => _changes;

  @visibleForTesting
  Future<void> initWithBox(Box<Map> box) async {
    _box = box;
    _changes.bind(_box.listenable());
    _ready = true;
  }

  ValueListenable<Box<Map>> listenable() => _box.listenable();

  List<NoteAuditEvent> getAll() {
    if (!_ready) return const [];
    return _box.values
        .map((raw) => NoteAuditEvent.fromMap(Map<dynamic, dynamic>.from(raw)))
        .toList(growable: false);
  }

  List<NoteAuditEvent> forNote(String noteId) {
    final rows = getAll().where((item) => item.noteId == noteId).toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<void> addAll(List<NoteAuditEvent> events) async {
    if (!_ready) return;
    for (final event in events) {
      await _box.put(event.id, event.toMap());
    }
  }

  Future<void> recordDiff({
    required NoteItem? previous,
    required NoteItem next,
    DateTime? now,
  }) async {
    if (!_ready) return;
    final kinds = diffNoteAudits(previous, next);
    if (kinds.isEmpty) return;
    final created = now ?? DateTime.now();
    await addAll([
      for (final kind in kinds)
        NoteAuditEvent(
          id: _uuid.v4(),
          noteId: next.id,
          kind: kind,
          createdAt: created,
          summary: noteAuditSummary(kind),
        ),
    ]);
  }

  Future<void> deleteForNote(String noteId) async {
    if (!_ready) return;
    for (final item in forNote(noteId)) {
      await _box.delete(item.id);
    }
  }

  Future<void> saveFromSync(Map<String, dynamic> map) async {
    if (!_ready) return;
    final item = NoteAuditEvent.fromMap(map);
    await _box.put(item.id, item.toMap());
  }

  Future<void> deleteFromSync(String id) async {
    if (!_ready) return;
    await _box.delete(id);
  }

  List<Map<String, dynamic>> exportAllMaps() {
    return getAll().map((item) => item.toMap()).toList(growable: false);
  }

  Future<void> replaceAllFromMaps(List<Map<String, dynamic>> maps) async {
    if (!_ready) return;
    await _box.clear();
    for (final map in maps) {
      final item = NoteAuditEvent.fromMap(map);
      await _box.put(item.id, item.toMap());
    }
  }

  Future<void> resetAll() async {
    if (!_ready) return;
    await _box.clear();
  }

  @visibleForTesting
  Future<void> clear() => resetAll();
}
