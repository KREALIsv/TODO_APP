import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'features/auth/data/auth_session_repository.dart';
import 'features/notes/data/attachments_repository.dart';
import 'features/notes/data/day_entries_repository.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/tags_repository.dart';
import 'features/notes/data/task_reminders_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/sync/data/device_identity.dart';
import 'features/sync/data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HiveLogger.level = HiveLoggerLevel.warn;
  await Hive.initFlutter();
  await Future.wait([
    NotesRepository.instance.init(),
    DayEntriesRepository.instance.init(),
    TagsRepository.instance.init(),
    AttachmentsRepository.instance.init(),
    SettingsRepository.instance.init(),
    AuthSessionRepository.instance.init(),
    DeviceIdentity.instance.init(),
  ]);
  await SyncService.instance.init();
  unawaited(_postBootstrap());
  runApp(const TodosApp());
}

Future<void> _postBootstrap() async {
  try {
    await TagsRepository.instance.ensureTags(
      NotesRepository.instance.getAllTags(),
    );
    await TaskRemindersService.instance.init();
    await NotesRepository.instance.syncAllReminders();
  } catch (e, st) {
    debugPrint('Post-bootstrap skipped: $e\n$st');
  }
}
