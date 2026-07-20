import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/tags_repository.dart';
import 'features/notes/data/task_reminders_service.dart';
import 'features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await NotesRepository.instance.init();
  await TagsRepository.instance.init();
  await SettingsRepository.instance.init();
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
