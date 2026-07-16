import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/note_item.dart';

class NotesRepository {
  NotesRepository._();

  static final NotesRepository instance = NotesRepository._();

  static const String _boxName = 'notes';

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

  List<NoteItem> getAll() {
    final items = _box.values
        .map((raw) => NoteItem.fromMap(Map<dynamic, dynamic>.from(raw)))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  NoteItem? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return NoteItem.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  Future<void> add(NoteItem item) async {
    await _box.put(item.id, item.toMap());
  }

  Future<void> update(NoteItem item) async {
    await _box.put(item.id, item.toMap());
  }

  Future<void> delete(String id) async {
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
    await update(
      current.copyWith(
        completed: !current.completed,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box.clear();
  }
}
