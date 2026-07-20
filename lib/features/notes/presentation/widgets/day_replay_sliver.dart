import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../data/notes_repository.dart';
import '../../domain/day_entry.dart';
import '../../domain/day_log.dart';
import '../../domain/note_item.dart';
import '../../domain/date_only.dart';
import '../../domain/reminder_offset.dart';
import '../../domain/task_dates.dart';
import 'day_outcome_meta.dart';
import 'note_card_context_sheet.dart';
import 'task_section_header.dart';

/// Past-day Diario: pinned notes as reference, then day log rows with outcomes.
class DayReplaySliver extends StatelessWidget {
  const DayReplaySliver({
    super.key,
    required this.rows,
    required this.onOpen,
    this.emptyMessage = 'Nada registrado este día',
  });

  final List<DayLogRow> rows;
  final void Function(NoteItem item) onOpen;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pinned = rows.where((r) => r.note.pinned).toList(growable: false);
    final rest = rows.where((r) => !r.note.pinned).toList(growable: false);

    if (rows.isEmpty) {
      return _DayEmptySliver(
        message: emptyMessage,
        icon: Icons.menu_book_outlined,
      );
    }

    return _PinnedThenBodySliver(
      pinnedHeader: 'Fijadas',
      bodyHeader: 'Diario',
      pinnedChild: pinned.isEmpty
          ? null
          : _DayLogList(rows: pinned, onOpen: onOpen, bottomPadding: 0),
      bodyChild: rest.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                child: Text(
                  pinned.isEmpty
                      ? emptyMessage
                      : 'Sin más entradas este día',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral60,
                  ),
                ),
              ),
            )
          : _DayLogList(rows: rest, onOpen: onOpen),
    );
  }
}

/// Future-day agenda: tasks committed/due on [day].
class DayPlanSliver extends StatelessWidget {
  const DayPlanSliver({
    super.key,
    required this.day,
    required this.items,
    required this.onOpen,
  });

  final DateTime day;
  final List<NoteItem> items;
  final void Function(NoteItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return const _DayEmptySliver(
        message: 'Nada para este día',
        icon: Icons.event_outlined,
      );
    }

    final pinned = items.where((n) => n.pinned).toList();
    final rest = items.where((n) => !n.pinned).toList();

    return _PinnedThenBodySliver(
      pinnedHeader: 'Fijadas',
      bodyHeader: 'Para este día',
      bodySubtitle: 'Lo que ya tienes pendiente',
      pinnedChild: pinned.isEmpty
          ? null
          : _PlanList(
              day: day,
              items: pinned,
              onOpen: onOpen,
              bottomPadding: 0,
            ),
      bodyChild: rest.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                child: Text(
                  'Sin más pendientes',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral60,
                  ),
                ),
              ),
            )
          : _PlanList(day: day, items: rest, onOpen: onOpen),
    );
  }
}

class _DayEmptySliver extends StatelessWidget {
  const _DayEmptySliver({
    required this.message,
    this.icon,
  });

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 48, color: AppColors.neutral40),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.neutral60,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedThenBodySliver extends StatefulWidget {
  const _PinnedThenBodySliver({
    required this.pinnedHeader,
    required this.bodyHeader,
    this.bodySubtitle,
    required this.pinnedChild,
    required this.bodyChild,
  });

  final String pinnedHeader;
  final String bodyHeader;
  final String? bodySubtitle;
  final Widget? pinnedChild;
  final Widget bodyChild;

  @override
  State<_PinnedThenBodySliver> createState() => _PinnedThenBodySliverState();
}

class _PinnedThenBodySliverState extends State<_PinnedThenBodySliver> {
  bool _pinnedExpanded = true;
  bool _bodyExpanded = true;

  @override
  Widget build(BuildContext context) {
    final collapsible = widget.pinnedChild != null;
    return SliverMainAxisGroup(
      slivers: [
        if (widget.pinnedChild != null) ...[
          SliverToBoxAdapter(
            child: TaskSectionHeader(
              title: widget.pinnedHeader,
              expanded: collapsible ? _pinnedExpanded : null,
              onToggle: collapsible
                  ? () => setState(() => _pinnedExpanded = !_pinnedExpanded)
                  : null,
            ),
          ),
          if (!collapsible || _pinnedExpanded) widget.pinnedChild!,
        ],
        SliverToBoxAdapter(
          child: TaskSectionHeader(
            title: widget.bodyHeader,
            subtitle: widget.bodySubtitle,
            expanded: collapsible ? _bodyExpanded : null,
            onToggle: collapsible
                ? () => setState(() => _bodyExpanded = !_bodyExpanded)
                : null,
          ),
        ),
        if (!collapsible || _bodyExpanded) widget.bodyChild,
      ],
    );
  }
}

class _DayLogList extends StatelessWidget {
  const _DayLogList({
    required this.rows,
    required this.onOpen,
    this.bottomPadding = 88,
  });

  final List<DayLogRow> rows;
  final void Function(NoteItem item) onOpen;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DayLogCard(row: row, onTap: () => onOpen(row.note)),
          );
        },
      ),
    );
  }
}

class _DayLogCard extends StatelessWidget {
  const _DayLogCard({required this.row, required this.onTap});

  final DayLogRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final note = row.note;
    final entry = row.entry;
    final struck = DayOutcomeStyle.isStruck(entry.outcome);
    final titleColor = DayOutcomeStyle.titleColor(entry.outcome);
    final canReview = note.type == NoteType.task &&
        !note.isArchived &&
        entry.outcome == DayOutcome.open;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: ThemeTokens.borderRadius,
      child: InkWell(
        onTap: onTap,
        onLongPress: canReview
            ? () {
                showNoteCardContextSheet(
                  context,
                  item: note,
                  repository: NotesRepository.instance,
                  actionDay: entry.day,
                );
              }
            : null,
        borderRadius: ThemeTokens.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Icon(
                  DayOutcomeStyle.leadingIconFor(entry.outcome),
                  size: 22,
                  color: entry.outcome == DayOutcome.completed
                      ? AppColors.primary60
                      : AppColors.neutral40,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.displayTitle,
                            style: textTheme.labelLarge?.copyWith(
                              decoration: struck
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    DayOutcomeMeta(entry: entry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({
    required this.day,
    required this.items,
    required this.onOpen,
    this.bottomPadding = 88,
  });

  final DateTime day;
  final List<NoteItem> items;
  final void Function(NoteItem item) onOpen;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PlanTaskCard(
              item: item,
              day: day,
              onTap: () => onOpen(item),
            ),
          );
        },
      ),
    );
  }
}

class _PlanTaskCard extends StatelessWidget {
  const _PlanTaskCard({
    required this.item,
    required this.day,
    required this.onTap,
  });

  final NoteItem item;
  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: ThemeTokens.borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: ThemeTokens.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: false,
                    onChanged: null,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayTitle,
                            style: textTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _PlanTaskMeta(item: item, day: day),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTaskMeta extends StatelessWidget {
  const _PlanTaskMeta({
    required this.item,
    required this.day,
  });

  final NoteItem item;
  final DateTime day;

  String _formatTime(DateTime due) {
    final hour = due.hour;
    final minute = due.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute ${isPm ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    final dayKey = dateOnly(day);
    final isCommitment =
        item.todayAt != null && dateOnly(item.todayAt!) == dayKey;
    final isDue = item.dueAt != null && dateOnly(item.dueAt!) == dayKey;

    Widget label({
      required String text,
      required Color color,
      IconData? icon,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      );
    }

    final parts = <Widget>[
      label(
        text: 'Tarea',
        color: AppColors.neutral60,
        icon: Icons.check_circle_outline,
      ),
    ];

    if (isCommitment) {
      parts.addAll([
        Text(' · ', style: textTheme.labelSmall),
        label(
          text: 'Para este día',
          color: accent,
          icon: Icons.wb_sunny_outlined,
        ),
      ]);
    }

    if (isDue && item.dueHasTime) {
      parts.addAll([
        Text(' · ', style: textTheme.labelSmall),
        label(
          text: 'A las ${_formatTime(item.dueAt!)}',
          color: AppColors.neutral60,
          icon: Icons.schedule,
        ),
      ]);
    }

    if (item.hasReminder) {
      parts.addAll([
        const SizedBox(width: 4),
        const Icon(
          Icons.notifications_none,
          size: 12,
          color: AppColors.neutral60,
        ),
      ]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts,
    );
  }
}
