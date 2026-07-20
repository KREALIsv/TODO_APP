import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../notes/domain/date_only.dart';

/// Header date control: chevrons ±1 day, tappable label → date picker,
/// optional "Hoy" chip when [selectedDay] is not today.
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

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOnly(selectedDay),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDayChanged(dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final day = dateOnly(selectedDay);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Día anterior',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => onDayChanged(day.subtract(const Duration(days: 1))),
          icon: Icon(
            Icons.chevron_left,
            color: scheme.primary,
            size: 22,
          ),
        ),
        Flexible(
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                formatHeaderDate(day),
                style: textStyle ??
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Día siguiente',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => onDayChanged(day.add(const Duration(days: 1))),
          icon: Icon(
            Icons.chevron_right,
            color: scheme.primary,
            size: 22,
          ),
        ),
        if (!_isToday)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: ActionChip(
              label: const Text('Hoy'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () => onDayChanged(dateOnly(today)),
              backgroundColor: AppColors.primary00,
              side: BorderSide.none,
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }
}
