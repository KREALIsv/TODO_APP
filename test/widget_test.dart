import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:todos_app/app/app.dart';
import 'package:todos_app/features/home/presentation/home_screen.dart';
import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/settings/data/settings_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('widget_test_hive_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<Map>('notes');
    await NotesRepository.instance.initWithBox(box);
    await NotesRepository.instance.clear();
    final dayBox = await Hive.openBox<Map>('day_entries');
    await DayEntriesRepository.instance.initWithBox(dayBox);
    await DayEntriesRepository.instance.clear();
    final settingsBox = await Hive.openBox('settings');
    await SettingsRepository.instance.initWithBox(settingsBox);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Home shows quick capture field and filter chips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: NotesRepository.instance),
      ),
    );

    expect(find.text('Escribe una nota…'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Tu primera nota está a un tap'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Fijadas'), findsOneWidget);
    expect(find.text('Notas'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
  });

  testWidgets('Home expands search field when search icon is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: NotesRepository.instance),
      ),
    );

    expect(find.text('Buscar notas…'), findsNothing);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar notas…'), findsOneWidget);
  });

  testWidgets('TodosApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TodosApp());
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
