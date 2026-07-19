import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/date_only.dart';
import '../../domain/note_item.dart';
import '../../domain/reminder_offset.dart';
import '../../domain/task_dates.dart';
import 'relative_time.dart';

class TaskDateMeta extends StatelessWidget {
  const TaskDateMeta({
    super.key,
    required this.item,
    this.now,
  });

  final NoteItem item;
  final DateTime? now;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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
    final reference = now ?? DateTime.now();
    final today = dateOnly(reference);

    Widget meta({
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

    Widget withReminder(Widget child) {
      if (!item.hasReminder) return child;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(width: 4),
          const Icon(
            Icons.notifications_none,
            size: 12,
            color: AppColors.neutral60,
          ),
        ],
      );
    }

    if (item.isOverdue(reference)) {
      final d = item.dueAt!;
      final label = item.dueHasTime
          ? (item.isDueToday(reference)
              ? 'Vencida · ${_formatTime(d)}'
              : 'Vencida · ${d.day} ${_months[d.month - 1]}')
          : '${d.day} ${_months[d.month - 1]}';
      return withReminder(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule,
                size: 12,
                color: AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (item.isDueToday(reference)) {
      if (item.dueHasTime) {
        return withReminder(
          meta(
            text: _formatTime(item.dueAt!),
            color: AppColors.primary,
            icon: Icons.schedule,
          ),
        );
      }
      return withReminder(
        meta(
          text: 'Vence hoy',
          color: AppColors.primary,
        ),
      );
    }

    if (item.dueAt != null && dateOnly(item.dueAt!).isAfter(today)) {
      final d = item.dueAt!;
      return withReminder(
        meta(
          text: '${d.day} ${_months[d.month - 1]}',
          color: AppColors.neutral60,
        ),
      );
    }

    // Undated: relative time + optional today commitment icon.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isTodayCommitment(reference)) ...[
          const Icon(Icons.wb_sunny_outlined, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
        ],
        Text(
          formatRelativeTime(item.updatedAt, now: reference),
          style: textTheme.labelSmall,
        ),
      ],
    );
  }
}
