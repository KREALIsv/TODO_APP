import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../data/day_entries_repository.dart';
import '../../domain/date_only.dart';
import '../../domain/day_entry.dart';
import 'day_outcome_meta.dart';

/// Chronological day log for a single task (BuJo history inside the card sheet).
class TaskDayHistorySection extends StatelessWidget {
  const TaskDayHistorySection({
    super.key,
    required this.noteId,
    this.dayEntriesRepository,
    this.onDayTap,
    this.maxVisible = 6,
  });

  final String noteId;
  final DayEntriesRepository? dayEntriesRepository;
  final ValueChanged<DateTime>? onDayTap;
  final int maxVisible;

  DayEntriesRepository get _dayEntries =>
      dayEntriesRepository ?? DayEntriesRepository.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dayEntries.changes,
      builder: (context, _) {
        final entries = _dayEntries.entriesForNote(noteId);
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Sin días registrados aún. Aparecerán aquí cuando planifiques, '
              'migres o completes esta tarea en un día.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
            ),
          );
        }

        final visible = entries.take(maxVisible).toList(growable: false);
        final hiddenCount = entries.length - visible.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Text(
                  'Historial de días',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final entry in visible)
                _TaskDayHistoryTile(
                  entry: entry,
                  onTap: onDayTap == null
                      ? null
                      : () => onDayTap!(dateOnly(entry.day)),
                ),
              if (hiddenCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Text(
                    '+ $hiddenCount día${hiddenCount == 1 ? '' : 's'} más',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppSurface.secondary(context),
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskDayHistoryTile extends StatelessWidget {
  const _TaskDayHistoryTile({
    required this.entry,
    this.onTap,
  });

  final DayEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canNavigate = onTap != null;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: onTap,
      title: Text(
        formatDayMonthYear(entry.day),
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: DayOutcomeMeta(entry: entry),
      trailing: canNavigate
          ? Icon(
              Icons.chevron_right,
              size: 18,
              color: AppSurface.secondary(context),
            )
          : null,
    );
  }
}
