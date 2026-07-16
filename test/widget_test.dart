import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:todos_app/app/app.dart';
import 'package:todos_app/features/home/presentation/home_screen.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('widget_test_hive_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<Map>('notes');
    await NotesRepository.instance.initWithBox(box);
    await NotesRepository.instance.clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Home shows quick capture field', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: NotesRepository.instance),
      ),
    );

    expect(find.text('Escribe una nota…'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Tu primera nota está a un tap'), findsOneWidget);
  });

  testWidgets('TodosApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TodosApp());
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
