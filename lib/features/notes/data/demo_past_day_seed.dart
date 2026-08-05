import 'package:flutter/foundation.dart';

import '../domain/date_only.dart';
import '../domain/day_entry.dart';
import '../domain/note_item.dart';
import 'day_entries_repository.dart';
import 'notes_repository.dart';
import 'tags_repository.dart';

/// Dev-only seed so Home can show unfinished past-day mute in the real UI.
/// Trigger with `?seedPastMute=1` (web).
abstract final class DemoPastDaySeed {
  static const _markerId = 'demo-past-mute-marker';

  static bool get shouldSeed {
    if (!kIsWeb) return false;
    return Uri.base.queryParameters['seedPastMute'] == '1';
  }

  static DateTime get pastDay => dateOnly(DateTime(2026, 7, 31));

  static Future<void> seedIfRequested() async {
    if (!shouldSeed) return;
    final notes = NotesRepository.instance;
    final days = DayEntriesRepository.instance;
    final tags = TagsRepository.instance;

    if (notes.getById(_markerId) != null) return;

    await tags.ensureTags(['IMPERQUIMIA', 'SYVEX', 'KREALI']);
    final day = pastDay;
    final now = DateTime.now();

    final open1 = NoteItem(
      id: 'demo-past-open-1',
      type: NoteType.task,
      title: 'Responderles a los de plg',
      body: '',
      pinned: false,
      completed: false,
      createdAt: day.subtract(const Duration(days: 3)),
      updatedAt: now,
      dueAt: day,
      tags: const ['IMPERQUIMIA'],
    );
    final open2 = NoteItem(
      id: 'demo-past-open-2',
      type: NoteType.task,
      title: 'Responderle a pasante',
      body: '',
      pinned: false,
      completed: false,
      createdAt: day.subtract(const Duration(days: 4)),
      updatedAt: now,
      dueAt: day,
      tags: const ['SYVEX'],
    );
    final done = NoteItem(
      id: 'demo-past-done-1',
      type: NoteType.task,
      title: 'darle feedback a gaby',
      body: '',
      pinned: false,
      completed: true,
      createdAt: day.subtract(const Duration(days: 2)),
      updatedAt: now,
      dueAt: day,
      completedAt: day.add(const Duration(hours: 16)),
      tags: const ['KREALI'],
    );
    final marker = NoteItem(
      id: _markerId,
      type: NoteType.note,
      title: 'demo seed',
      body: 'seedPastMute',
      pinned: false,
      completed: false,
      createdAt: now,
      updatedAt: now,
      archivedAt: now,
    );

    await notes.add(open1);
    await notes.add(open2);
    await notes.add(done);
    await notes.add(marker);

    await days.ensurePlanned(
      noteId: open1.id,
      day: day,
      via: DayVia.due,
      now: day,
    );
    await days.ensurePlanned(
      noteId: open2.id,
      day: day,
      via: DayVia.due,
      now: day,
    );
    await days.markCompleted(
      noteId: done.id,
      day: day,
      outcomeAt: day.add(const Duration(hours: 16)),
      via: DayVia.due,
    );
  }
}
