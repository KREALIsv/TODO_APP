import 'package:flutter/material.dart';

import '../../data/day_entries_repository.dart';
import '../../domain/date_only.dart';
import '../../domain/day_log.dart';
import '../../domain/day_view_query.dart';
import '../../domain/note_item.dart';

/// Resolves which calendar day «Quitar del día» should target.
///
/// Uses [preferredDay] when set (Home day selector / context sheet). When
/// several open days exist and there is no preferred day, asks the user.
Future<DateTime?> resolveRemoveFromDay(
  BuildContext context, {
  required NoteItem item,
  DateTime? preferredDay,
  DayEntriesRepository? dayEntriesRepository,
}) async {
  if (preferredDay != null) return dateOnly(preferredDay);

  final dayEntries = dayEntriesRepository ?? DayEntriesRepository.instance;
  final candidates = DayViewQuery.removeFromDayCandidates(
    item: item,
    entries: dayEntries.entriesForNote(item.id),
  );

  if (candidates.isEmpty) {
    return commitmentDayFor(item, DateTime.now());
  }
  if (candidates.length == 1) return candidates.first;

  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                '¿De qué día quitar la tarea?',
                style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final day in candidates)
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(formatDayMonthYear(day)),
                onTap: () => Navigator.pop(sheetContext, day),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
