import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/date_only.dart';

enum TaskWhenKind { today, tomorrow, date, someday }

/// Exclusive «¿Cuándo?» selector for tasks.
class TaskWhenField extends StatelessWidget {
  const TaskWhenField({
    super.key,
    required this.dueAt,
    required this.dueHasTime,
    required this.todayOn,
    required this.onChanged,
  });

  final DateTime? dueAt;
  final bool dueHasTime;
  final bool todayOn;
  final void Function({
    required bool todayOn,
    DateTime? dueAt,
    bool dueHasTime,
  }) onChanged;

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

  String _formatDateChip(DateTime due, bool hasTime) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final dueDay = dateOnly(due);
    final dateLabel = dueDay == today
        ? 'Vence hoy'
        : 'Vence ${due.day} ${_months[due.month - 1]}';
    if (!hasTime) return dateLabel;
    final hour = due.hour;
    final minute = due.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final time = '$h12:$minute ${isPm ? 'PM' : 'AM'}';
    return dueDay == today ? 'Vence hoy · $time' : '$dateLabel · $time';
  }

  void _selectToday() {
    onChanged(todayOn: true, dueAt: null, dueHasTime: false);
  }

  void _selectTomorrow() {
    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    onChanged(todayOn: false, dueAt: tomorrow, dueHasTime: false);
  }

  void _selectSomeday() {
    onChanged(todayOn: false, dueAt: null, dueHasTime: false);
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = dueAt ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: dateOnly(initial),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !context.mounted) return;

    if (dueHasTime && dueAt != null) {
      onChanged(
        todayOn: false,
        dueAt: DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          dueAt!.hour,
          dueAt!.minute,
        ),
        dueHasTime: true,
      );
      return;
    }

    onChanged(
      todayOn: false,
      dueAt: DateTime(pickedDate.year, pickedDate.month, pickedDate.day),
      dueHasTime: false,
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    if (dueAt == null) return;
    final now = DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: dueHasTime
          ? TimeOfDay.fromDateTime(dueAt!)
          : TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null || !context.mounted) return;
    onChanged(
      todayOn: false,
      dueAt: DateTime(
        dueAt!.year,
        dueAt!.month,
        dueAt!.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
      dueHasTime: true,
    );
  }

  void _clearTime() {
    if (dueAt == null) return;
    onChanged(
      todayOn: false,
      dueAt: dateOnly(dueAt!),
      dueHasTime: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _selected;
    final showDateDetails = selected == TaskWhenKind.date && dueAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Cuándo?', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Hoy'),
              selected: selected == TaskWhenKind.today,
              onSelected: (_) => _selectToday(),
              selectedColor: AppColors.primary00,
              checkmarkColor: AppColors.primary,
            ),
            ChoiceChip(
              label: const Text('Mañana'),
              selected: selected == TaskWhenKind.tomorrow,
              onSelected: (_) => _selectTomorrow(),
              selectedColor: AppColors.primary00,
              checkmarkColor: AppColors.primary,
            ),
            ChoiceChip(
              label: Text(
                showDateDetails
                    ? _formatDateChip(dueAt!, dueHasTime)
                    : 'Fecha…',
              ),
              selected: selected == TaskWhenKind.date,
              onSelected: (_) => _pickDate(context),
              selectedColor: AppColors.primary00,
              checkmarkColor: AppColors.primary,
            ),
            ChoiceChip(
              label: const Text('Algún día'),
              selected: selected == TaskWhenKind.someday,
              onSelected: (_) => _selectSomeday(),
              selectedColor: AppColors.primary00,
              checkmarkColor: AppColors.primary,
            ),
          ],
        ),
        if (showDateDetails) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: const Text('Cambiar fecha'),
              ),
              if (!dueHasTime)
                TextButton.icon(
                  onPressed: () => _pickTime(context),
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: const Text('+ Hora'),
                )
              else
                TextButton.icon(
                  onPressed: _clearTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Quitar hora'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
