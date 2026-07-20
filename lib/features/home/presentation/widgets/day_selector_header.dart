import 'package:flutter/material.dart';

import '../../../notes/domain/date_only.dart';

/// Header date control: chevrons ±1 day, tappable date → picker.
class DaySelectorHeader extends StatelessWidget {
  const DaySelectorHeader({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.onDayChanged,
    this.textStyle,
  });

  final DateTime selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDayChanged;
  final TextStyle? textStyle;

  bool get _isToday => dateOnly(selectedDay) == dateOnly(today);

  void _goToToday() => onDayChanged(dateOnly(today));

  Future<void> _openPicker(BuildContext context) async {
    final todayDate = dateOnly(today);
    var draft = dateOnly(selectedDay);

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Elegir día'),
          content: SizedBox(
            width: 320,
            height: 360,
            child: CalendarDatePicker(
              initialDate: draft,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              currentDate: todayDate,
              onDateChanged: (value) => draft = dateOnly(value),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, todayDate),
              child: const Text('Hoy'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, draft),
                  child: const Text('Ver'),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (picked != null) {
      onDayChanged(dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final day = dateOnly(selectedDay);
    final labelStyle = textStyle ??
        Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
            );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Día anterior',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => onDayChanged(day.subtract(const Duration(days: 1))),
          icon: Icon(Icons.chevron_left, color: scheme.primary, size: 24),
        ),
        Tooltip(
          message: _isToday
              ? 'Toca para elegir otra fecha'
              : 'Toca para elegir · mantén para ir a hoy',
          child: Material(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => _openPicker(context),
              onLongPress: _isToday ? null : _goToToday,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatHeaderDate(day),
                      style: labelStyle,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Día siguiente',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => onDayChanged(day.add(const Duration(days: 1))),
          icon: Icon(Icons.chevron_right, color: scheme.primary, size: 24),
        ),
      ],
    );
  }
}
