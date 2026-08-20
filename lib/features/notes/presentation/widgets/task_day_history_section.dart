import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../data/day_entries_repository.dart';
import '../../domain/date_only.dart';
import '../../domain/day_entry.dart';
import '../../domain/task_when_save_hint.dart';

/// Chronological day log for a single task (BuJo history, text-only).
class TaskDayHistorySection extends StatefulWidget {
  const TaskDayHistorySection({
    super.key,
    required this.noteId,
    this.dayEntriesRepository,
    this.onDayTap,
    this.collapsedCount = 3,
    this.expandable = true,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 4),
  });

  final String noteId;
  final DayEntriesRepository? dayEntriesRepository;
  final ValueChanged<DateTime>? onDayTap;
  final int collapsedCount;
  final bool expandable;
  final EdgeInsets padding;

  DayEntriesRepository get _dayEntries =>
      dayEntriesRepository ?? DayEntriesRepository.instance;

  @override
  State<TaskDayHistorySection> createState() => _TaskDayHistorySectionState();
}

class _TaskDayHistorySectionState extends State<TaskDayHistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget._dayEntries.changes,
      builder: (context, _) {
        final entries = widget._dayEntries.entriesForNote(widget.noteId);
        if (entries.isEmpty) {
          return Padding(
            padding: widget.padding,
            child: Text(
              'Sin días registrados aún. Aparecerán aquí cuando planifiques, '
              'migres o completes esta tarea en un día.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
            ),
          );
        }

        final canCollapse =
            widget.expandable && entries.length > widget.collapsedCount;
        final visible = !canCollapse || _expanded
            ? entries
            : entries.take(widget.collapsedCount).toList(growable: false);
        final hiddenCount = entries.length - visible.length;

        return Padding(
          padding: widget.padding,
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
                TaskDayHistoryTile(
                  entry: entry,
                  onTap: widget.onDayTap == null
                      ? null
                      : () => widget.onDayTap!(dateOnly(entry.day)),
                ),
              if (canCollapse && !_expanded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = true),
                    child: Text(
                      hiddenCount == 1
                          ? 'Ver más (1 día)'
                          : 'Ver más ($hiddenCount días)',
                    ),
                  ),
                )
              else if (canCollapse && _expanded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = false),
                    child: const Text('Ver menos'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TaskDayHistoryTile extends StatelessWidget {
  const TaskDayHistoryTile({
    super.key,
    required this.entry,
    this.onTap,
  });

  final DayEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final outcomeLabel = dayOutcomeShortLabel(entry);
    final dimmed = entry.outcome == DayOutcome.open ||
        entry.outcome == DayOutcome.cancelled ||
        entry.outcome == DayOutcome.backlogged;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: onTap,
      title: Text(
        formatDayMonthYear(entry.day),
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          decoration: entry.outcome == DayOutcome.completed ||
                  entry.outcome == DayOutcome.cancelled
              ? TextDecoration.lineThrough
              : null,
          color: dimmed ? AppSurface.secondary(context) : null,
        ),
      ),
      subtitle: Text(
        outcomeLabel,
        style: textTheme.bodySmall?.copyWith(
          color: AppSurface.secondary(context),
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              size: 18,
              color: AppSurface.secondary(context),
            )
          : null,
    );
  }
}
