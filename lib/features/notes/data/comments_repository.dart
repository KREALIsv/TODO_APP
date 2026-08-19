import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_repo_notifier.dart';
import '../domain/note_comment.dart';
import 'attachments_repository.dart';

class CommentsRepository {
  CommentsRepository._();

  static final CommentsRepository instance = CommentsRepository._();

  static const String boxName = 'comments';
  static const _uuid = Uuid();

  late Box<Map> _box;
  final _changes = HiveRepoNotifier();
  AttachmentsRepository _attachments = AttachmentsRepository.instance;
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

  @visibleForTesting
  set attachmentsForTests(AttachmentsRepository repo) {
    _attachments = repo;
  }

  ValueListenable<Box<Map>> listenable() => _box.listenable();

  List<NoteComment> getAll() {
    if (!_ready) return const [];
    return _box.values
        .map((raw) => NoteComment.fromMap(Map<dynamic, dynamic>.from(raw)))
        .toList(growable: false);
  }

  NoteComment? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return NoteComment.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  List<NoteComment> forNote(String noteId) {
    final rows = getAll().where((item) => item.noteId == noteId).toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<NoteComment> add({
    required String noteId,
    required String body,
    DateTime? now,
    String? id,
  }) async {
    final trimmed = body.trim();
    if (trimmed.length > NoteComment.maxBodyLength) {
      throw StateError('El comentario es demasiado largo');
    }
    final created = now ?? DateTime.now();
    final comment = NoteComment(
      id: id ?? _uuid.v4(),
      noteId: noteId,
      body: trimmed,
      createdAt: created,
    );
    await _box.put(comment.id, comment.toMap());
    return comment;
  }

  Future<NoteComment> updateBody(String id, String body, {DateTime? now}) async {
    final current = getById(id);
    if (current == null) {
      throw StateError('Comentario no encontrado');
    }
    final trimmed = body.trim();
    if (trimmed.length > NoteComment.maxBodyLength) {
      throw StateError('El comentario es demasiado largo');
    }
    final next = current.copyWith(
      body: trimmed,
      editedAt: now ?? DateTime.now(),
    );
    await _box.put(next.id, next.toMap());
    return next;
  }

  Future<void> delete(String id) async {
    await _attachments.deleteForComment(id);
    await _box.delete(id);
  }

  Future<void> deleteForNote(String noteId) async {
    if (!_ready) return;
    for (final item in forNote(noteId)) {
      await delete(item.id);
    }
  }

  Future<void> saveFromSync(Map<String, dynamic> map) async {
    if (!_ready) return;
    final item = NoteComment.fromMap(map);
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
      final item = NoteComment.fromMap(map);
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
