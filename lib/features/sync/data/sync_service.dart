import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../auth/data/auth_service.dart';
import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/data/tags_repository.dart';
import '../../notes/domain/note_item.dart';
import 'wodo_api_config.dart';

enum SyncState { unavailable, idle, syncing, error }

class SyncService extends ChangeNotifier {
  SyncService._();

  static final instance = SyncService._();
  static const _boxName = 'sync_state';
  static const _snapshotKey = 'snapshot';
  static const _cursorKey = 'cursor';

  final AuthService _auth = AuthService.instance;
  final NotesRepository _notes = NotesRepository.instance;
  final TagsRepository _tags = TagsRepository.instance;
  final DayEntriesRepository _dayEntries = DayEntriesRepository.instance;

  late Box<dynamic> _box;
  Timer? _debounce;
  bool _wasAuthenticated = false;
  SyncState _state = SyncState.unavailable;
  String? _errorMessage;
  bool _syncing = false;

  SyncState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => WodoApiConfig.isConfigured && _auth.isAuthenticated;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _auth.addListener(_onAuthChanged);
    _notes.listenable().addListener(_scheduleSync);
    _tags.listenable().addListener(_scheduleSync);
    _dayEntries.listenable().addListener(_scheduleSync);
    Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    _wasAuthenticated = _auth.isAuthenticated;
    _onAuthChanged();
  }

  Future<void> syncNow() async {
    if (_syncing || !isAvailable) return;
    _syncing = true;
    _state = SyncState.syncing;
    _errorMessage = null;
    notifyListeners();
    try {
      final token = await _auth.accessToken();
      if (token == null) return;
      final beforePull = _snapshot();
      await _push(token, beforePull);
      await _pull(token, beforePull);
      await _box.put(_snapshotKey, _snapshot());
      _state = SyncState.idle;
    } catch (error) {
      _state = SyncState.error;
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Map<String, Map<String, Map<String, dynamic>>> _snapshot() {
    final notes = <String, Map<String, dynamic>>{
      for (final item in _notes.exportAllMaps()) item['id'] as String: item,
    };
    final tags = <String, Map<String, dynamic>>{
      for (final name in _tags.getAll())
        _tagId(name): {
          'name': name,
          'colorId': _tags.getColorId(name),
          'opacity': _tags.getOpacity(name),
        },
    };
    final dayEntries = <String, Map<String, dynamic>>{
      for (final entry in _dayEntries.getAll()) entry.id: entry.toMap(),
    };
    return {'note': notes, 'tag': tags, 'dayEntry': dayEntries};
  }

  Future<void> _push(
    String token,
    Map<String, Map<String, Map<String, dynamic>>> current,
  ) async {
    final previous = _readSnapshot();
    final mutations = <Map<String, dynamic>>[];
    for (final entityType in current.keys) {
      final before =
          previous[entityType] ?? const <String, Map<String, dynamic>>{};
      final after =
          current[entityType] ?? const <String, Map<String, dynamic>>{};
      for (final entry in after.entries) {
        if (_sameMap(before[entry.key], entry.value)) continue;
        mutations.add(
          _mutation(
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
          _mutation(
            entityType: entityType,
            entityId: entityId,
            operation: 'DELETE',
          ),
        );
      }
    }
    for (var index = 0; index < mutations.length; index += 100) {
      final end = index + 100 > mutations.length
          ? mutations.length
          : index + 100;
      final batch = mutations.sublist(index, end);
      await _request('sync/push', token: token, body: {'mutations': batch});
    }
  }

  Future<void> _pull(
    String token,
    Map<String, Map<String, Map<String, dynamic>>> beforePull,
  ) async {
    String? cursor = _box.get(_cursorKey) as String?;
    do {
      final payload = await _request(
        'sync/pull',
        token: token,
        query: {'cursor': ?cursor},
      );
      final data = payload['data'];
      if (data is! List) return;
      for (final item in data.whereType<Map>()) {
        await _applyRemote(Map<String, dynamic>.from(item), beforePull);
      }
      cursor = payload['nextCursor'] as String?;
      if (cursor != null) await _box.put(_cursorKey, cursor);
    } while (cursor != null);
  }

  Future<void> _applyRemote(
    Map<String, dynamic> mutation,
    Map<String, Map<String, Map<String, dynamic>>> beforePull,
  ) async {
    final entityType = mutation['entityType'] as String?;
    final entityId = mutation['entityId'] as String?;
    final operation = mutation['operation'] as String?;
    final rawPayload = mutation['payload'];
    if (entityType == null || entityId == null || operation == null) return;
    if (operation == 'DELETE') {
      switch (entityType) {
        case 'note':
          await _notes.delete(entityId);
          break;
        case 'tag':
          final name = beforePull['tag']?[entityId]?['name'];
          if (name is String) await _tags.remove(name);
          break;
        case 'dayEntry':
          await _dayEntries.deleteFromSync(entityId);
          break;
      }
      return;
    }
    if (rawPayload is! Map) return;
    final payload = Map<String, dynamic>.from(rawPayload);
    switch (entityType) {
      case 'note':
        await _applyRemoteNote(
          entityId,
          payload,
          beforePull['note']?[entityId],
        );
        break;
      case 'tag':
        final name = payload['name'];
        if (name is String && name.trim().isNotEmpty) {
          await _tags.ensureTag(
            name,
            colorId: payload['colorId'] as String?,
            opacity: (payload['opacity'] as num?)?.toDouble(),
          );
        }
        break;
      case 'dayEntry':
        await _dayEntries.saveFromSync(payload);
        break;
    }
  }

  Future<void> _applyRemoteNote(
    String entityId,
    Map<String, dynamic> payload,
    Map<String, dynamic>? synced,
  ) async {
    final remote = NoteItem.fromMap(payload);
    final local = _notes.getById(entityId);
    if (local != null && synced != null && !_sameMap(local.toMap(), synced)) {
      final remoteChangedAt = remote.updatedAt;
      if (!remoteChangedAt.isAfter(local.updatedAt)) return;
      final conflict = local.copyWith(
        id: const Uuid().v4(),
        title: 'Conflicto de sincronización · ${local.displayTitle}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _notes.saveFromSync(conflict);
    }
    await _notes.saveFromSync(remote);
  }

  Map<String, Map<String, Map<String, dynamic>>> _readSnapshot() {
    final raw = _box.get(_snapshotKey);
    if (raw is! Map) return {};
    return {
      for (final section in raw.entries)
        section.key.toString(): {
          for (final item
              in (section.value as Map?)?.entries ??
                  const <MapEntry<dynamic, dynamic>>[])
            item.key.toString(): Map<String, dynamic>.from(item.value as Map),
        },
    };
  }

  Map<String, dynamic> _mutation({
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
  }) {
    final source = jsonEncode([entityType, entityId, operation, payload]);
    return {
      'clientMutationId': sha256.convert(utf8.encode(source)).toString(),
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': ?payload,
    };
  }

  bool _sameMap(Map<String, dynamic>? first, Map<String, dynamic>? second) {
    if (first == null || second == null) return first == second;
    return jsonEncode(first) == jsonEncode(second);
  }

  String _tagId(String name) => 'tag_${name.trim().toLowerCase()}';

  Future<Map<String, dynamic>> _request(
    String path, {
    required String token,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = WodoApiConfig.uri(path, query);
    final response = body == null
        ? await http.get(uri, headers: {'Authorization': 'Bearer $token'})
        : await http.post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        (decoded['message'] ?? 'Error de sincronización.').toString(),
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'La respuesta de sincronización no es válida.',
      );
    }
    return data;
  }

  void _scheduleSync() {
    if (!isAvailable) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), syncNow);
  }

  void _onAuthChanged() {
    final authenticated = _auth.isAuthenticated;
    if (authenticated && !_wasAuthenticated) {
      unawaited(_box.delete(_cursorKey));
      unawaited(_box.delete(_snapshotKey));
    }
    _wasAuthenticated = authenticated;
    _state = isAvailable ? SyncState.idle : SyncState.unavailable;
    notifyListeners();
    if (isAvailable) unawaited(syncNow());
  }
}
