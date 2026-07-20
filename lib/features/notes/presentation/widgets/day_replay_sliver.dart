import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../domain/day_entry.dart';
import '../../domain/day_log.dart';
import '../../domain/note_item.dart';
import 'day_outcome_meta.dart';
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

/// Future-day plan: tasks committed/due on that day.
class DayPlanSliver extends StatelessWidget {
  const DayPlanSliver({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<NoteItem> items;
  final void Function(NoteItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return const _DayEmptySliver(
        message: 'Nada planificado este día',
      );
    }

    final pinned = items.where((n) => n.pinned).toList();
    final rest = items.where((n) => !n.pinned).toList();

    return _PinnedThenBodySliver(
      pinnedHeader: 'Fijadas',
      bodyHeader: 'Plan',
      pinnedChild: pinned.isEmpty
          ? null
          : _PlanList(items: pinned, onOpen: onOpen, bottomPadding: 0),
      bodyChild: rest.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                child: Text(
                  'Sin más tareas este día',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral60,
                  ),
                ),
              ),
            )
          : _PlanList(items: rest, onOpen: onOpen),
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

class _PinnedThenBodySliver extends StatelessWidget {
  const _PinnedThenBodySliver({
    required this.pinnedHeader,
    required this.bodyHeader,
    required this.pinnedChild,
    required this.bodyChild,
  });

  final String pinnedHeader;
  final String bodyHeader;
  final Widget? pinnedChild;
  final Widget bodyChild;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        if (pinnedChild != null) ...[
          SliverToBoxAdapter(
            child: TaskSectionHeader(title: pinnedHeader),
          ),
          pinnedChild!,
        ],
        SliverToBoxAdapter(
          child: TaskSectionHeader(title: bodyHeader),
        ),
        bodyChild,
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
    required this.items,
    required this.onOpen,
    this.bottomPadding = 88,
  });

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
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: ThemeTokens.borderRadius,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: ThemeTokens.borderRadius,
                ),
                title: Text(item.displayTitle),
                trailing: item.pinned
                    ? Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => onOpen(item),
              ),
            ),
          );
        },
      ),
    );
  }
}
