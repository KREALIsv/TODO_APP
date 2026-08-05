import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:todos_app/core/theme/theme.dart';
import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/data/tags_repository.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_card.dart';

/// Visual comparison: today's live pending card vs past-day unfinished mute.
void main() {
  late Directory tempDir;
  late TagsRepository tagsRepo;
  late AttachmentsRepository attachmentsRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('past_day_muted_visual_');
    Hive.init(tempDir.path);
    tagsRepo = TagsRepository.instance;
    await tagsRepo.initWithBox(
      await Hive.openBox<dynamic>('tags_past_day_muted_visual'),
    );
    await tagsRepo.clear();
    await tagsRepo.ensureTags(['IMPERQUIMIA', 'SYVEX', 'KREALI']);
    await tagsRepo.setColor('IMPERQUIMIA', 'red');
    await tagsRepo.setColor('SYVEX', 'gray');
    await tagsRepo.setColor('KREALI', 'green');

    attachmentsRepo = AttachmentsRepository.instance;
    await attachmentsRepo.initWithBoxes(
      meta: await Hive.openBox<Map>('att_meta_past_day_muted'),
      blobs: await Hive.openBox<dynamic>('att_blob_past_day_muted'),
    );
    await attachmentsRepo.clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('past-day unfinished cards use muted title colors (no Opacity)', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 5, 12);
    final pastDay = DateTime(2026, 7, 31);

    final liveTask = NoteItem(
      id: 'live',
      type: NoteType.task,
      title: 'Responderles a los de plg',
      body: '',
      pinned: false,
      completed: false,
      createdAt: pastDay,
      updatedAt: today,
      todayAt: today,
      tags: const ['IMPERQUIMIA'],
    );
    final pastOpenTask = NoteItem(
      id: 'past-open',
      type: NoteType.task,
      title: 'Responderles a los de plg',
      body: '',
      pinned: false,
      completed: false,
      createdAt: pastDay,
      updatedAt: today,
      tags: const ['IMPERQUIMIA'],
    );
    final pastCompleted = NoteItem(
      id: 'past-done',
      type: NoteType.task,
      title: 'darle feedback a gaby',
      body: '',
      pinned: false,
      completed: true,
      createdAt: pastDay,
      updatedAt: today,
      completedAt: pastDay,
      tags: const ['KREALI'],
    );
    final pastOpenEntry = DayEntry(
      id: 'e-open',
      noteId: pastOpenTask.id,
      day: pastDay,
      via: DayVia.manual,
      outcome: DayOutcome.open,
      createdAt: pastDay,
    );
    final pastDoneEntry = DayEntry(
      id: 'e-done',
      noteId: pastCompleted.id,
      day: pastDay,
      via: DayVia.manual,
      outcome: DayOutcome.completed,
      outcomeAt: pastDay,
      createdAt: pastDay,
    );

    await tester.binding.setSurfaceSize(const Size(420, 720));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            final sectionStyle = Theme.of(context).textTheme.titleSmall;
            return Scaffold(
              backgroundColor: const Color(0xFFF6F8FA),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Text('Hoy (pendiente viva)', style: sectionStyle),
                    const SizedBox(height: 8),
                    NoteCard(
                      item: liveTask,
                      tagsRepository: tagsRepo,
                      attachmentsRepository: attachmentsRepo,
                      viewDay: today,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '31 Jul (pasado: no cumplida → tenue)',
                      style: sectionStyle,
                    ),
                    const SizedBox(height: 8),
                    NoteCard(
                      item: pastOpenTask,
                      tagsRepository: tagsRepo,
                      attachmentsRepository: attachmentsRepo,
                      viewDay: pastDay,
                      dayEntry: pastOpenEntry,
                      onTap: () {},
                    ),
                    NoteCard(
                      item: NoteItem(
                        id: 'past-open-2',
                        type: NoteType.task,
                        title: 'Responderle a pasante',
                        body: '',
                        pinned: false,
                        completed: false,
                        createdAt: pastDay.subtract(const Duration(days: 1)),
                        updatedAt: today,
                        tags: const ['SYVEX'],
                      ),
                      tagsRepository: tagsRepo,
                      attachmentsRepository: attachmentsRepo,
                      viewDay: pastDay,
                      dayEntry: DayEntry(
                        id: 'e-open-2',
                        noteId: 'past-open-2',
                        day: pastDay,
                        via: DayVia.manual,
                        outcome: DayOutcome.open,
                        createdAt: pastDay,
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    Text('31 Jul (completada del día)', style: sectionStyle),
                    const SizedBox(height: 8),
                    NoteCard(
                      item: pastCompleted,
                      tagsRepository: tagsRepo,
                      attachmentsRepository: attachmentsRepo,
                      viewDay: pastDay,
                      dayEntry: pastDoneEntry,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pendiente'), findsNWidgets(2));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/past_day_incomplete_muted.png'),
    );
  });
}
