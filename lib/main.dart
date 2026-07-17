import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/tags_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await NotesRepository.instance.init();
  await TagsRepository.instance.init();
  // Migra tags ya usados en notas al catálogo (instalaciones previas).
  await TagsRepository.instance.ensureTags(
    NotesRepository.instance.getAllTags(),
  );
  runApp(const TodosApp());
}
