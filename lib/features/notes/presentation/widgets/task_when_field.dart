import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../domain/date_only.dart';
import 'task_dates_sheet.dart';

enum TaskWhenKind { today, tomorrow, date, someday }

/// Exclusive «¿Cuándo?» selector for tasks.
class TaskWhenField extends StatelessWidget {
  const TaskWhenField({
    super.key,
    required this.dueAt,
    required this.dueHasTime,
    required this.todayOn,
    required this.onChanged,
    this.reminderMinutesBefore,
  });

  final DateTime? dueAt;
  final bool dueHasTime;
  final bool todayOn;
  final int? reminderMinutesBefore;
  final void Function({
    required bool todayOn,
    DateTime? dueAt,
    bool dueHasTime,
    int? reminderMinutesBefore,
  }) onChanged;

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Resolve UI kind from persisted fields (edit hydration).
  static TaskWhenKind kindOf({
    required bool todayOn,
    DateTime? dueAt,
    bool dueHasTime = false,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    if (todayOn) return TaskWhenKind.today;
    if (dueAt != null) {
      final tomorrow = dateOnly(reference).add(const Duration(days: 1));
      if (dateOnly(dueAt) == tomorrow && !dueHasTime) {
        return TaskWhenKind.tomorrow;
      }
      return TaskWhenKind.date;
    }
    return TaskWhenKind.someday;
  }

  TaskWhenKind get _selected => kindOf(
        todayOn: todayOn,
        dueAt: dueAt,
        dueHasTime: dueHasTime,
      );

  /// Same shape for any calendar day (`19 jul` / `19 jul, 9:00 AM`).
  static String formatDueLabel(DateTime due, {bool hasTime = false}) {
    final dateLabel = '${due.day} ${_months[due.month - 1]}';
    if (!hasTime) return dateLabel;
    return '$dateLabel, ${_formatTime(due)}';
  }

  static String _formatTime(DateTime due) {
    final hour = due.hour;
    final minute = due.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute ${isPm ? 'PM' : 'AM'}';
  }

  static bool isOverdueDue({
    required DateTime dueAt,
    required bool dueHasTime,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    if (dueHasTime) return !dueAt.isAfter(reference);
    return dateOnly(dueAt).isBefore(dateOnly(reference));
  }

  String get _fieldLabel {
    switch (_selected) {
      case TaskWhenKind.today:
        return 'Hoy';
      case TaskWhenKind.someday:
        return 'Sin fecha';
      case TaskWhenKind.tomorrow:
      case TaskWhenKind.date:
        return formatDueLabel(dueAt!, hasTime: dueHasTime);
    }
  }

  bool get _isPlaceholder => _selected == TaskWhenKind.someday;

  bool get _showOverdue =>
      dueAt != null &&
      !todayOn &&
      isOverdueDue(dueAt: dueAt!, dueHasTime: dueHasTime);

  void _selectToday() {
    onChanged(
      todayOn: true,
      dueAt: null,
      dueHasTime: false,
      reminderMinutesBefore: null,
    );
  }

  void _selectTomorrow() {
    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    onChanged(
      todayOn: false,
      dueAt: tomorrow,
      dueHasTime: false,
      reminderMinutesBefore: reminderMinutesBefore,
    );
  }

  void _selectSomeday() {
    onChanged(
      todayOn: false,
      dueAt: null,
      dueHasTime: false,
      reminderMinutesBefore: null,
    );
  }

  Future<void> _openConfiguration(BuildContext context) async {
    final result = await showTaskDatesSheet(
      context,
      dueAt: dueAt,
      dueHasTime: dueHasTime,
      reminderMinutesBefore: reminderMinutesBefore,
    );
    if (result == null || !context.mounted) return;

    if (result.clearDate) {
      onChanged(
        todayOn: false,
        dueAt: null,
        dueHasTime: false,
        reminderMinutesBefore: null,
      );
      return;
    }

    onChanged(
      todayOn: false,
      dueAt: result.dueAt,
      dueHasTime: result.dueHasTime,
      reminderMinutesBefore: result.reminderMinutesBefore,
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.primary00,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.neutral80,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary20 : AppColors.neutral20,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Cuándo?', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              label: 'Hoy',
              selected: selected == TaskWhenKind.today,
              onSelected: _selectToday,
            ),
            _chip(
              label: 'Mañana',
              selected: selected == TaskWhenKind.tomorrow,
              onSelected: _selectTomorrow,
            ),
            _chip(
              label: 'Fecha',
              selected: selected == TaskWhenKind.date,
              onSelected: () => _openConfiguration(context),
            ),
            _chip(
              label: 'Algún día',
              selected: selected == TaskWhenKind.someday,
              onSelected: _selectSomeday,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _WhenValueField(
          label: _fieldLabel,
          isPlaceholder: _isPlaceholder,
          showOverdue: _showOverdue,
          onTap: () => _openConfiguration(context),
        ),
      ],
    );
  }
}

/// Input-like value row (same radius/border language as text fields).
class _WhenValueField extends StatelessWidget {
  const _WhenValueField({
    required this.label,
    required this.isPlaceholder,
    required this.showOverdue,
    required this.onTap,
  });

  final String label;
  final bool isPlaceholder;
  final bool showOverdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: ThemeTokens.borderRadius,
        side: BorderSide(color: AppColors.neutral20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: ThemeTokens.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isPlaceholder
                        ? AppColors.neutral40
                        : AppColors.neutral100,
                  ),
                ),
              ),
              if (showOverdue) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Plazo vencido',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.expand_more,
                size: 22,
                color: AppColors.neutral60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
