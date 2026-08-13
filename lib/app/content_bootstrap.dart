import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/notes/data/attachments_repository.dart';
import '../features/notes/data/day_entries_repository.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/data/tags_repository.dart';
import '../features/notes/data/task_reminders_service.dart';
import '../features/sync/data/local_tab_sync_service.dart';
import '../features/sync/data/sync_service.dart';

bool _contentOpened = false;
bool _postContentDone = false;

/// Opens Hive boxes that hold user content (encrypted when LDEK is in memory).
Future<void> openContentRepositories({bool force = false}) async {
  if (_contentOpened && !force) return;
  await Future.wait([
    NotesRepository.instance.init(),
    DayEntriesRepository.instance.init(),
    TagsRepository.instance.init(),
    AttachmentsRepository.instance.init(),
  ]);
  _contentOpened = true;
}

/// Sync, tab-reload and reminders — only after content boxes are open.
Future<void> runPostContentBootstrap() async {
  if (_postContentDone) return;
  _postContentDone = true;
  try {
    await SyncService.instance.init();
    await LocalTabSyncService.instance.init();
    await TagsRepository.instance.ensureTags(
      NotesRepository.instance.getAllTags(),
    );
    await TaskRemindersService.instance.init();
    await NotesRepository.instance.syncAllReminders();
  } catch (e, st) {
    debugPrint('Post-bootstrap skipped: $e\n$st');
  }
}

@visibleForTesting
void debugResetContentBootstrap() {
  _contentOpened = false;
  _postContentDone = false;
}
