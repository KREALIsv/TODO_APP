import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../settings/presentation/data_backup.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/domain/auth_session_expired_exception.dart';
import '../../encryption/data/crypto_service.dart';
import '../../encryption/data/vault_service.dart';
import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/data/tags_repository.dart';
import '../../notes/domain/note_item.dart';
import '../domain/account_switch_gate.dart';
import '../domain/sync_conflict.dart';
import '../domain/sync_snapshot.dart';
import '../domain/sync_tags.dart';
import 'device_identity.dart';
import 'device_registry.dart';
import 'wodo_api_config.dart';

enum SyncState { unavailable, idle, syncing, error, accountSwitchRequired }

class SyncService extends ChangeNotifier {
  SyncService._();

  static final instance = SyncService._();
  static const _boxName = 'sync_state';
  static const _snapshotKey = 'snapshot';
  static const _cursorKey = 'cursor';
  static const _accountEmailKey = 'account_email';
  static const _pendingSwitchFromKey = 'account_switch_from';
  static const _pendingSwitchToKey = 'account_switch_to';

  final AuthService _auth = AuthService.instance;
  final NotesRepository _notes = NotesRepository.instance;
  final TagsRepository _tags = TagsRepository.instance;
  final DayEntriesRepository _dayEntries = DayEntriesRepository.instance;

  late Box<dynamic> _box;
  Timer? _debounce;
  SyncState _state = SyncState.unavailable;
  String? _errorMessage;
  bool _syncing = false;

  SyncState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isAvailable =>
      WodoApiConfig.isConfigured &&
      _auth.isAuthenticated &&
      DeviceIdentity.instance.syncEnabled;
  bool get requiresAccountSwitch => _state == SyncState.accountSwitchRequired;
  bool get canSync => isAvailable && !requiresAccountSwitch;

  AccountSwitchPrompt? get pendingAccountSwitch {
    final from = _box.get(_pendingSwitchFromKey) as String?;
    final to = _box.get(_pendingSwitchToKey) as String?;
    if (from == null || to == null) return null;
    return AccountSwitchPrompt(fromEmail: from, toEmail: to);
  }

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _auth.addListener(_onAuthChanged);
    _notes.changes.addListener(_scheduleSync);
    _tags.changes.addListener(_scheduleSync);
    _dayEntries.changes.addListener(_scheduleSync);
    DeviceIdentity.instance.addListener(_onSyncEligibilityChanged);
    Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    _onAuthChanged();
  }

  Future<void> syncNow() async {
    if (_syncing || !canSync) return;
    final vault = VaultService.instance;
    if (vault.blocksEncryptedSync) {
      _state = SyncState.unavailable;
      _errorMessage =
          'Vincula este dispositivo o usa tu código de recuperación para sincronizar.';
      notifyListeners();
      return;
    }
    _syncing = true;
    _state = SyncState.syncing;
    _errorMessage = null;
    notifyListeners();
    try {
      final token = await _auth.accessToken();
      if (token == null) return;
      await DeviceRegistry.instance.register();
      final beforePull = _snapshot();
      await _push(token, beforePull);
      await _pull(token, beforePull);
      await _box.put(_snapshotKey, _snapshot());
      await _markBoundToCurrentAccount();
      _state = SyncState.idle;
    } on AuthSessionExpiredException {
      _state = SyncState.unavailable;
      _errorMessage = null;
    } catch (error) {
      _state = SyncState.error;
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Clears sync cursors so the next sync re-pushes the full local snapshot
  /// (used after enabling E2EE so payloads go up encrypted).
  Future<void> resetAndSync() async {
    await _box.delete(_cursorKey);
    await _box.delete(_snapshotKey);
    await syncNow();
  }

  Map<String, Map<String, Map<String, dynamic>>> _snapshot() {
    final notes = buildSyncNoteSection(_notes.exportAllMaps());
    final tags = <String, Map<String, dynamic>>{
      for (final name in _tags.getAll())
        tagSyncEntityId(name): {
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
    final rawPrevious = _readSnapshotRaw();
    final previous = sanitizeSyncSnapshot(rawPrevious);
    var mutations = buildSyncPushMutations(
      previous: previous,
      current: current,
      mutationBuilder: ({
        required entityType,
        required entityId,
        required operation,
        payload,
      }) =>
          _mutation(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
      ),
    );
    mutations = withConflictCopyCleanupDeletes(
      rawPrevious: rawPrevious,
      mutations: mutations,
      deleteBuilder: ({
        required entityType,
        required entityId,
        required operation,
      }) =>
          _mutation(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
      ),
    );
    for (var index = 0; index < mutations.length; index++) {
      final mutation = mutations[index];
      final payload = mutation['payload'];
      if (payload is! Map<String, dynamic>) continue;
      mutations[index] = _mutation(
        entityType: mutation['entityType'] as String,
        entityId: mutation['entityId'] as String,
        operation: mutation['operation'] as String,
        payload: await _wirePayload(
          entityType: mutation['entityType'] as String,
          entityId: mutation['entityId'] as String,
          plaintext: payload,
        ),
      );
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
    final updatedDuringPull = <String>{};
    String? cursor = _box.get(_cursorKey) as String?;
    do {
      final payload = await _request(
        'sync/pull',
        token: token,
        query: {
          if (cursor != null) 'cursor': cursor,
          'appUserId': DeviceIdentity.instance.appUserId,
        },
      );
      final data = payload['data'];
      if (data is! List) return;
      for (final item in data.whereType<Map>()) {
        await _applyRemote(
          Map<String, dynamic>.from(item),
          beforePull,
          updatedDuringPull,
        );
      }
      cursor = payload['nextCursor'] as String?;
      if (cursor != null) await _box.put(_cursorKey, cursor);
    } while (cursor != null);
  }

  Future<void> _applyRemote(
    Map<String, dynamic> mutation,
    Map<String, Map<String, Map<String, dynamic>>> beforePull,
    Set<String> updatedDuringPull,
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
          final name = resolveTagNameForDelete(
            entityId: entityId,
            beforePullTags: beforePull['tag'],
            catalogNames: _tags.getAll(),
          );
          if (name != null) await _tags.remove(name);
          break;
        case 'dayEntry':
          await _dayEntries.deleteFromSync(entityId);
          break;
      }
      return;
    }
    if (rawPayload is! Map) return;
    var payload = Map<String, dynamic>.from(rawPayload);
    final vault = VaultService.instance;
    if (CryptoService.instance.isOpaqueEnvelope(payload)) {
      if (!vault.canSyncEncrypted) return;
      final decrypted = await vault.decryptSyncPayload(
        payload: payload,
        entityType: entityType,
        entityId: entityId,
      );
      if (decrypted == null) return;
      payload = decrypted;
    } else if (vault.accountEncryptionEnabled) {
      // Legacy plaintext left on server after enabling E2EE — ignore.
      return;
    }
    switch (entityType) {
      case 'note':
        await _applyRemoteNote(
          entityId,
          payload,
          beforePull['note']?[entityId],
          updatedDuringPull,
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

  Future<Map<String, dynamic>> _wirePayload({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> plaintext,
  }) async {
    final vault = VaultService.instance;
    if (!vault.canSyncEncrypted) return plaintext;
    final encrypted = await vault.encryptSyncPayload(
      payload: plaintext,
      entityType: entityType,
      entityId: entityId,
    );
    return encrypted ?? plaintext;
  }

  Future<void> _applyRemoteNote(
    String entityId,
    Map<String, dynamic> payload,
    Map<String, dynamic>? synced,
    Set<String> updatedDuringPull,
  ) async {
    if (shouldIgnoreRemoteNoteMutation(payload)) return;

    final remote = NoteItem.fromMap(payload);
    final local = _notes.getById(entityId);
    if (shouldCreateSyncConflict(
      local: local,
      syncedSnapshot: synced,
      remote: remote,
      entityUpdatedDuringPull: updatedDuringPull.contains(entityId),
    )) {
      await _notes.saveFromSync(
        buildSyncConflictCopy(
          local!,
          id: const Uuid().v4(),
          originalNoteId: entityId,
        ),
      );
    }
    await _notes.saveFromSync(remote);
    updatedDuringPull.add(entityId);
  }

  Map<String, Map<String, Map<String, dynamic>>> _readSnapshot() {
    return sanitizeSyncSnapshot(_readSnapshotRaw());
  }

  Map<String, Map<String, Map<String, dynamic>>> _readSnapshotRaw() {
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

  Future<Map<String, dynamic>> _request(
    String path, {
    required String token,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = WodoApiConfig.uri(path, query);
    final response = await _auth.authorizedRequest(
      (resolvedToken) => body == null
          ? http.get(uri, headers: {'Authorization': 'Bearer $resolvedToken'})
          : http.post(
              uri,
              headers: {
                'Authorization': 'Bearer $resolvedToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            ),
    );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'La respuesta de sincronización no es válida.',
      );
    }
    return data;
  }

  void _scheduleSync() {
    if (!canSync) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), syncNow);
  }

  Future<void> resolveAccountSwitchUploadLocal() async {
    final prompt = pendingAccountSwitch;
    if (prompt == null) return;
    await _clearPendingAccountSwitch();
    await _resetSyncProgress();
    await _markBoundToCurrentAccount();
    _state = SyncState.idle;
    notifyListeners();
    await syncNow();
  }

  Future<void> resolveAccountSwitchDownloadCloud() async {
    final prompt = pendingAccountSwitch;
    if (prompt == null) return;
    await _clearPendingAccountSwitch();
    await _resetSyncProgress();
    await resetAllAppContent(
      notes: _notes,
      tags: _tags,
      dayEntries: _dayEntries,
    );
    await _markBoundToCurrentAccount();
    _state = SyncState.idle;
    notifyListeners();
    await syncNow();
  }

  Future<void> resolveAccountSwitchKeepLocalPaused() async {
    final prompt = pendingAccountSwitch;
    if (prompt == null) return;
    await _clearPendingAccountSwitch();
    await DeviceIdentity.instance.setSyncEnabled(false);
    _state = SyncState.unavailable;
    notifyListeners();
  }

  void _onSyncEligibilityChanged() {
    if (!_auth.isAuthenticated) return;
    if (_evaluateAndApplyAccountSwitchGate()) return;
    _scheduleSync();
  }

  void _onAuthChanged() {
    final authenticated = _auth.isAuthenticated;
    if (!authenticated) {
      unawaited(_clearPendingAccountSwitch());
      _state = SyncState.unavailable;
      notifyListeners();
      return;
    }

    if (_evaluateAndApplyAccountSwitchGate()) return;

    _state = isAvailable ? SyncState.idle : SyncState.unavailable;
    notifyListeners();
    if (canSync) unawaited(syncNow());
  }

  bool _evaluateAndApplyAccountSwitchGate() {
    final restored = pendingAccountSwitch;
    if (restored != null) {
      _state = SyncState.accountSwitchRequired;
      notifyListeners();
      return true;
    }

    final email = _auth.userEmail;
    final boundEmail = _box.get(_accountEmailKey) as String?;
    final prompt = detectAccountSwitchPrompt(
      boundAccountEmail: boundEmail,
      currentEmail: email,
      hasLocalContent: deviceHasAccountSpecificContent(
        notes: _notes,
        dayEntries: _dayEntries,
      ),
    );
    if (prompt != null) {
      unawaited(_setPendingAccountSwitch(prompt));
      _state = SyncState.accountSwitchRequired;
      notifyListeners();
      return true;
    }

    if (boundEmail != null &&
        email != null &&
        boundEmail.trim().toLowerCase() != email.trim().toLowerCase()) {
      unawaited(_resetSyncProgress());
      unawaited(_markBoundToCurrentAccount());
    }

    return false;
  }

  Future<void> _setPendingAccountSwitch(AccountSwitchPrompt prompt) async {
    await _box.put(_pendingSwitchFromKey, prompt.fromEmail);
    await _box.put(_pendingSwitchToKey, prompt.toEmail);
  }

  Future<void> _clearPendingAccountSwitch() async {
    await _box.delete(_pendingSwitchFromKey);
    await _box.delete(_pendingSwitchToKey);
  }

  Future<void> _markBoundToCurrentAccount() async {
    final email = _auth.userEmail;
    if (email == null || email.isEmpty) return;
    await _box.put(_accountEmailKey, email.trim().toLowerCase());
  }

  Future<void> _resetSyncProgress() async {
    await _box.delete(_cursorKey);
    await _box.delete(_snapshotKey);
  }
}
