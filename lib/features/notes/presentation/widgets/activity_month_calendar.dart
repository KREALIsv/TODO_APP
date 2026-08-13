import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';
import '../../domain/activity_stats.dart';
import 'activity_heatmap.dart';

const _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const _weekdayLabels = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

/// Monthly activity calendar with heatmap cells (desktop profile sidebar).
class ActivityMonthCalendar extends StatefulWidget {
  const ActivityMonthCalendar({
    super.key,
    required this.eventCounts,
    this.selectedDay,
    this.onDaySelected,
    this.now,
  });

  final Map<DateTime, int> eventCounts;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onDaySelected;
  final DateTime? now;

  static const legendSteps = 9;

  @override
  State<ActivityMonthCalendar> createState() => _ActivityMonthCalendarState();
}

class _ActivityMonthCalendarState extends State<ActivityMonthCalendar> {
  late DateTime _visibleMonth;

  DateTime get _reference => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final anchor = widget.selectedDay ?? _reference;
    _visibleMonth = startOfMonth(anchor);
  }

  @override
  void didUpdateWidget(covariant ActivityMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final anchor = widget.selectedDay ?? _reference;
    final month = startOfMonth(anchor);
    if (widget.selectedDay != oldWidget.selectedDay &&
        month != _visibleMonth) {
      _visibleMonth = month;
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  String _monthTitle(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final days = monthGridDays(_visibleMonth);
    final selectedKey =
        widget.selectedDay != null ? dateOnly(widget.selectedDay!) : null;
    final todayKey = dateOnly(_reference);
    final visibleMonthKey = startOfMonth(_visibleMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Calendario de actividad',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppSurface.title(context),
                ),
              ),
            ),
            Tooltip(
              message:
                  'Intensidad según notas creadas o actualizadas ese día. '
                  'Toca un día para ir a esa fecha.',
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: AppSurface.mutedIcon(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _monthTitle(_visibleMonth),
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppSurface.title(context),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppSurface.secondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 4.0;
            final cellSize =
                ((constraints.maxWidth - gap * 6) / 7).clamp(0.0, 48.0);
            final rowCount = (days.length / 7).ceil();

            return Column(
              children: [
                for (var row = 0; row < rowCount; row++) ...[
                  if (row > 0) const SizedBox(height: gap),
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++) ...[
                        if (col > 0) SizedBox(width: gap),
                        _DayCell(
                          day: days[row * 7 + col],
                          count: widget.eventCounts[dateOnly(days[row * 7 + col])] ??
                              0,
                          inVisibleMonth:
                              startOfMonth(days[row * 7 + col]) == visibleMonthKey,
                          isSelected: selectedKey != null &&
                              dateOnly(days[row * 7 + col]) == selectedKey,
                          isToday:
                              dateOnly(days[row * 7 + col]) == todayKey,
                          size: cellSize,
                          onTap: widget.onDaySelected == null
                              ? null
                              : () => widget.onDaySelected!(
                                    dateOnly(days[row * 7 + col]),
                                  ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _MonthCalendarLegend(scheme: scheme),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.inVisibleMonth,
    required this.isSelected,
    required this.isToday,
    required this.size,
    this.onTap,
  });

  final DateTime day;
  final int count;
  final bool inVisibleMonth;
  final bool isSelected;
  final bool isToday;
  final double size;
  final VoidCallback? onTap;

  Color _numberColor(ColorScheme scheme) {
    if (!inVisibleMonth) {
      return scheme.brightness == Brightness.dark
          ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
          : AppColors.neutral60.withValues(alpha: 0.55);
    }
    if (scheme.brightness == Brightness.dark) {
      if (count <= 1) return scheme.onSurfaceVariant;
      return count < 30 ? AppColors.white : AppColors.neutral100;
    }
    return count <= 1 ? AppColors.neutral60 : AppColors.white;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = inVisibleMonth
        ? ActivityHeatmap.colorForCount(count, scheme)
        : AppSurface.heatmapEmpty(scheme);
    final numberColor = _numberColor(scheme);
    final radius = BorderRadius.circular((size * 0.18).clamp(3.0, 6.0));

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: isSelected
            ? Border.all(color: scheme.primary, width: 2)
            : isToday
                ? Border.all(
                    color: scheme.primary.withValues(alpha: 0.45),
                    width: 1,
                  )
                : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: numberColor,
          fontSize: (size * 0.38).clamp(9.0, 13.0),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );

    if (onTap != null) {
      cell = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: cell,
        ),
      );
    }

    return cell;
  }
}

class _MonthCalendarLegend extends StatelessWidget {
  const _MonthCalendarLegend({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppSurface.secondary(context),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Menos', style: style),
        const SizedBox(width: 6),
        for (var i = 0; i < ActivityMonthCalendar.legendSteps; i++) ...[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: ActivityHeatmap.colorForIntensity(
                i / (ActivityMonthCalendar.legendSteps - 1),
                scheme,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        const SizedBox(width: 2),
        Text('Más', style: style),
      ],
    );
  }
}
