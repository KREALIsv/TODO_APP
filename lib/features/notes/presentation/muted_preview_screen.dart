import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../domain/day_entry.dart';
import '../domain/note_item.dart';
import 'widgets/note_card.dart';

/// Temporary visual check for past-day unfinished mute (Opacity + colors).
/// Open with `?mutedPreview=1` on web.
class MutedPreviewScreen extends StatelessWidget {
  const MutedPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
    final pastOpen = NoteItem(
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
    final pastOpen2 = NoteItem(
      id: 'past-open-2',
      type: NoteType.task,
      title: 'Responderle a pasante',
      body: '',
      pinned: false,
      completed: false,
      createdAt: pastDay.subtract(const Duration(days: 1)),
      updatedAt: today,
      tags: const ['SYVEX'],
    );
    final pastDone = NoteItem(
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

    final theme = AppTheme.light();

    return MaterialApp(
      theme: theme,
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: AppBar(
          title: const Text('Preview mute día pasado'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hoy (pendiente viva)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            NoteCard(item: liveTask, viewDay: today, onTap: () {}),
            const SizedBox(height: 20),
            Text(
              '31 Jul (pasado: no cumplida → Opacity 0.72)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            NoteCard(
              item: pastOpen,
              viewDay: pastDay,
              dayEntry: DayEntry(
                id: 'e1',
                noteId: pastOpen.id,
                day: pastDay,
                via: DayVia.manual,
                outcome: DayOutcome.open,
                createdAt: pastDay,
              ),
              onTap: () {},
            ),
            NoteCard(
              item: pastOpen2,
              viewDay: pastDay,
              dayEntry: DayEntry(
                id: 'e2',
                noteId: pastOpen2.id,
                day: pastDay,
                via: DayVia.manual,
                outcome: DayOutcome.open,
                createdAt: pastDay,
              ),
              onTap: () {},
            ),
            const SizedBox(height: 12),
            Text(
              '31 Jul (completada del día)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            NoteCard(
              item: pastDone,
              viewDay: pastDay,
              dayEntry: DayEntry(
                id: 'e3',
                noteId: pastDone.id,
                day: pastDay,
                via: DayVia.manual,
                outcome: DayOutcome.completed,
                outcomeAt: pastDay,
                createdAt: pastDay,
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
