import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'features/auth/data/auth_session_repository.dart';
import 'features/billing/data/app_identity_repository.dart';
import 'features/billing/data/revenue_cat_config.dart';
import 'features/billing/data/subscription_service.dart';
import 'features/notes/data/day_entries_repository.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/tags_repository.dart';
import 'features/notes/data/task_reminders_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/sync/data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Silence IndexedDB open chatter ("Got object store…") in web consoles.
  HiveLogger.level = HiveLoggerLevel.warn;
  await Hive.initFlutter();
  await NotesRepository.instance.init();
  await DayEntriesRepository.instance.init();
  await TagsRepository.instance.init();
  await SettingsRepository.instance.init();
  await AppIdentityRepository.instance.init(
    overrideAppUserId: RevenueCatConfig.appUserIdOverride,
  );
  await AuthSessionRepository.instance.init();
  await SyncService.instance.init();
  unawaited(SubscriptionService.instance.refresh());
  // Migra tags ya usados en notas al catálogo (instalaciones previas).
  await TagsRepository.instance.ensureTags(
    NotesRepository.instance.getAllTags(),
  );
  // Best-effort: MissingPluginException after hot-reload is swallowed;
  // a full `flutter run` registers the native channel.
  try {
    await TaskRemindersService.instance.init();
    await NotesRepository.instance.syncAllReminders();
  } catch (e, st) {
    debugPrint('Reminders bootstrap skipped: $e\n$st');
  }
  runApp(const TodosApp());
}
