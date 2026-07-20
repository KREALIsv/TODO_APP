import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/date_only.dart';
import '../../domain/day_entry.dart';

/// Compact Bullet Journal–style outcome meta under a diary row title.
class DayOutcomeMeta extends StatelessWidget {
  const DayOutcomeMeta({super.key, required this.entry});

  final DayEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodySmall?.copyWith(color: AppColors.neutral60);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            DayOutcomeStyle.iconFor(entry.outcome),
            size: 14,
            color: AppColors.neutral40,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              DayOutcomeStyle.labelFor(entry),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual contrast + bujo semantics for diary rows.
class DayOutcomeStyle {
  const DayOutcomeStyle._();

  static bool isDimmed(DayOutcome outcome) =>
      outcome == DayOutcome.open ||
      outcome == DayOutcome.cancelled ||
      outcome == DayOutcome.backlogged;

  static bool isStruck(DayOutcome outcome) =>
      outcome == DayOutcome.completed || outcome == DayOutcome.cancelled;

  static Color titleColor(DayOutcome outcome) {
    if (outcome == DayOutcome.completed) return AppColors.neutral60;
    if (isDimmed(outcome)) return AppColors.neutral40;
    return AppColors.black;
  }

  static IconData iconFor(DayOutcome outcome) {
    switch (outcome) {
      case DayOutcome.open:
        return Icons.radio_button_unchecked;
      case DayOutcome.completed:
        return Icons.check_circle_outline;
      case DayOutcome.migrated:
        return Icons.chevron_right;
      case DayOutcome.scheduled:
        return Icons.event_outlined;
      case DayOutcome.cancelled:
        return Icons.remove_circle_outline;
      case DayOutcome.backlogged:
        return Icons.inbox_outlined;
    }
  }

  /// Leading glyph on the diary card (checkbox vs outcome icon).
  static IconData leadingIconFor(DayOutcome outcome) {
    switch (outcome) {
      case DayOutcome.open:
        return Icons.check_box_outline_blank;
      case DayOutcome.completed:
        return Icons.check_box;
      case DayOutcome.migrated:
      case DayOutcome.scheduled:
      case DayOutcome.cancelled:
      case DayOutcome.backlogged:
        return iconFor(outcome);
    }
  }

  static String labelFor(DayEntry entry) {
    switch (entry.outcome) {
      case DayOutcome.open:
        return 'Pendiente';
      case DayOutcome.completed:
        return 'Completada';
      case DayOutcome.migrated:
        final target = entry.targetDay;
        return target == null
            ? 'Migrada'
            : '→ ${formatDayMonth(target)}';
      case DayOutcome.scheduled:
        final target = entry.targetDay;
        return target == null
            ? 'Agendada'
            : '← ${formatDayMonth(target)}';
      case DayOutcome.cancelled:
        return 'Descartada';
      case DayOutcome.backlogged:
        return '→ Backlog';
    }
  }
}
