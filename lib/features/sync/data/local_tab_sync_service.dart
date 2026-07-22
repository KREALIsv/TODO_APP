import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/web/local_tab_sync.dart';
import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/data/tags_repository.dart';
import 'sync_service.dart';

/// Keeps open tabs of the same browser in sync (local-first, no server needed).
///
/// Works on the same origin (e.g. two `app.wodo.app` tabs). Does **not** sync
/// across devices or different browsers — that remains [SyncService]'s job.
class LocalTabSyncService {
  LocalTabSyncService._();

  static final instance = LocalTabSyncService._();

  Timer? _debounce;
  var _applyingPeerReload = false;
  var _initialized = false;

  final Listenable _changes = Listenable.merge([
    NotesRepository.instance.changes,
    TagsRepository.instance.changes,
    DayEntriesRepository.instance.changes,
  ]);

  void _onLocalChange() {
    if (_applyingPeerReload) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      LocalTabSyncPlatform.notifyPeerTabs();
    });
  }

  Future<void> _onPeerTabChange() async {
    if (_applyingPeerReload) return;
    _applyingPeerReload = true;
    _debounce?.cancel();
    try {
      await Future.wait([
        NotesRepository.instance.reloadFromPeerTab(),
        TagsRepository.instance.reloadFromPeerTab(),
        DayEntriesRepository.instance.reloadFromPeerTab(),
      ]);
      if (SyncService.instance.isAvailable) {
        await SyncService.instance.syncNow();
      }
    } catch (error, stack) {
      debugPrint('Local tab sync reload failed: $error\n$stack');
    } finally {
      _applyingPeerReload = false;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _changes.addListener(_onLocalChange);
    LocalTabSyncPlatform.init(() {
      unawaited(_onPeerTabChange());
    });
  }
}
