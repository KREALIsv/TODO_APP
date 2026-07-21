import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';

/// Shared layout math for [ActivityHeatmap] height and paint sizing.
class HeatmapLayout {
  const HeatmapLayout({
    required this.cellSize,
    required this.gridHeight,
    required this.gridWidth,
    required this.totalHeight,
  });

  final double cellSize;
  final double gridHeight;
  final double gridWidth;
  final double totalHeight;

  static const dayLabelGap = 4.0;
  static const monthToGridGap = 2.0;

  static HeatmapLayout? forConstraints({
    required double width,
    required int weeks,
    double maxHeight = double.infinity,
    double gap = 2.0,
    double dayLabelWidth = 12,
    double monthLabelHeight = 12,
    double maxCellSize = double.infinity,
  }) {
    if (weeks <= 0 || width <= 0) return null;

    final gridAreaWidth =
        (width - dayLabelWidth - dayLabelGap).clamp(1.0, double.infinity);
    final cellByWidth = (gridAreaWidth - gap * (weeks - 1)) / weeks;

    final hasHeightCap = maxHeight.isFinite;
    final gridBudget = hasHeightCap
        ? (maxHeight - monthLabelHeight - monthToGridGap).clamp(0.0, maxHeight)
        : double.infinity;
    final maxCellByHeight = hasHeightCap
        ? ((gridBudget - gap * 6) / 7).clamp(0.0, double.infinity)
        : cellByWidth;

    final cellSize =
        cellByWidth.clamp(0.0, maxCellByHeight).clamp(0.0, maxCellSize);
    if (hasHeightCap && maxHeight <= monthLabelHeight + monthToGridGap) {
      return null;
    }

    final gridHeight = cellSize * 7 + gap * 6;
    final gridWidth = cellSize * weeks + gap * (weeks - 1);
    final naturalHeight = monthLabelHeight + monthToGridGap + gridHeight;
    final totalHeight = hasHeightCap ? maxHeight : naturalHeight;

    return HeatmapLayout(
      cellSize: cellSize,
      gridHeight: gridHeight,
      gridWidth: gridWidth,
      totalHeight: totalHeight,
    );
  }

  /// Fixed cell size — used in desktop sidebar so squares stay mobile-sized.
  static HeatmapLayout forFixedCell({
    required double cellSize,
    required int weeks,
    double gap = 2.0,
    double monthLabelHeight = 12,
  }) {
    if (weeks <= 0 || cellSize <= 0) {
      return HeatmapLayout(
        cellSize: 0,
        gridHeight: 0,
        gridWidth: 0,
        totalHeight: monthLabelHeight,
      );
    }

    final gridHeight = cellSize * 7 + gap * 6;
    final gridWidth = cellSize * weeks + gap * (weeks - 1);
    final totalHeight = monthLabelHeight + monthToGridGap + gridHeight;

    return HeatmapLayout(
      cellSize: cellSize,
      gridHeight: gridHeight,
      gridWidth: gridWidth,
      totalHeight: totalHeight,
    );
  }

  static double heightForWidth({
    required double width,
    required int weeks,
    double gap = 2.0,
    double dayLabelWidth = 12,
    double monthLabelHeight = 12,
  }) {
    return forConstraints(
          width: width,
          weeks: weeks,
          gap: gap,
          dayLabelWidth: dayLabelWidth,
          monthLabelHeight: monthLabelHeight,
        )?.totalHeight ??
        monthLabelHeight;
  }

  /// Prefers [preferredMax], then [preferredMid], then the largest weeks count
  /// that keeps cells ≥ [minCell].
  static int weeksForMinCell({
    required double width,
    double gap = 3.0,
    double dayLabelWidth = 12,
    double minCell = 10,
    double maxCellSize = double.infinity,
    int preferredMax = 26,
    int preferredMid = 18,
  }) {
    for (final weeks in [preferredMax, preferredMid]) {
      final layout = forConstraints(
        width: width,
        weeks: weeks,
        gap: gap,
        dayLabelWidth: dayLabelWidth,
        maxCellSize: maxCellSize,
      );
      if (layout != null && layout.cellSize >= minCell) return weeks;
    }

    final gridAreaWidth =
        (width - dayLabelWidth - dayLabelGap).clamp(1.0, double.infinity);
    final maxWeeks =
        ((gridAreaWidth + gap) / (minCell + gap)).floor().clamp(1, preferredMid);
    return maxWeeks;
  }
}

/// GitHub-style contribution grid: month labels on top, weekday labels left.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.cells,
    required this.weeks,
    required this.rangeStart,
    this.gap = 2.0,
    this.dayLabelWidth = 12,
    this.monthLabelHeight = 12,
    this.showAllWeekdayLabels = false,
    this.showDayNumbers = false,
    this.onCellTap,
    this.semanticsLabel,
    this.fixedCellSize,
  });

  final List<int> cells;
  final int weeks;
  final DateTime rangeStart;
  final double gap;
  final double dayLabelWidth;
  final double monthLabelHeight;
  /// When set, cell size stays fixed (desktop sidebar) instead of filling width.
  final double? fixedCellSize;
  /// When true, labels every row (L–D) so each square maps to a weekday.
  final bool showAllWeekdayLabels;
  /// Opt-in calendar day numbers inside each cell (Profile / settings).
  final bool showDayNumbers;
  final void Function(DateTime day, int count)? onCellTap;
  final String? semanticsLabel;

  /// Sample counts for legends; must stay aligned with [colorForCount] bands.
  static const legendSampleCounts = [0, 1, 5, 15, 30];

  static const _sparseWeekdayLabels = ['L', '', 'X', '', 'V', '', ''];
  static const _fullWeekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _monthLabels = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static double heightForWidth({
    required double width,
    required int weeks,
    double gap = 2.0,
    double dayLabelWidth = 12,
    double monthLabelHeight = 12,
  }) =>
      HeatmapLayout.heightForWidth(
        width: width,
        weeks: weeks,
        gap: gap,
        dayLabelWidth: dayLabelWidth,
        monthLabelHeight: monthLabelHeight,
      );

  static Color colorForCount(int count, ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    if (count <= 0) {
      return AppSurface.heatmapEmpty(scheme);
    }

    if (isDark) {
      // Darker greens that read on #2D333B card surfaces.
      if (count == 1) return AppColors.primary80.withValues(alpha: 0.45);
      if (count < 10) return AppColors.primary80; // 2–9
      if (count < 30) return scheme.primary; // 10–29
      return AppColors.primary40; // 30+
    }

    // Wider bands so the darkest green is reserved for very active days.
    // Thresholds mirror [legendSampleCounts]: 0 / 1 / 5 / 15 / 30.
    if (count == 1) return AppColors.primary20;
    if (count < 10) return AppColors.primary40; // 2–9
    if (count < 30) return scheme.primary; // 10–29
    return AppColors.primary80; // 30+
  }

  /// Maps a 0..1 intensity (e.g. month count / max month) onto the heatmap palette.
  static Color colorForIntensity(double intensity, ColorScheme scheme) {
    if (intensity <= 0) {
      return colorForCount(legendSampleCounts[0], scheme);
    }
    if (intensity < 0.25) {
      return colorForCount(legendSampleCounts[1], scheme);
    }
    if (intensity < 0.5) {
      return colorForCount(legendSampleCounts[2], scheme);
    }
    if (intensity < 0.75) {
      return colorForCount(legendSampleCounts[3], scheme);
    }
    return colorForCount(legendSampleCounts[4], scheme);
  }

  List<String?> _monthLabelsForWeeks() {
    final labels = List<String?>.filled(weeks, null);
    var lastMonth = -1;
    for (var week = 0; week < weeks; week++) {
      final monday = rangeStart.add(Duration(days: week * 7));
      if (monday.month != lastMonth) {
        labels[week] = _monthLabels[monday.month - 1];
        lastMonth = monday.month;
      }
    }
    return labels;
  }

  (int week, int day)? _cellAt(Offset local, HeatmapLayout layout) {
    final gridLeft = dayLabelWidth + HeatmapLayout.dayLabelGap;
    final gridTop = monthLabelHeight + HeatmapLayout.monthToGridGap;
    final x = local.dx - gridLeft;
    final y = local.dy - gridTop;
    if (x < 0 || y < 0 || x > layout.gridWidth || y > layout.gridHeight) {
      return null;
    }
    final step = layout.cellSize + gap;
    final week = (x / step).floor();
    final day = (y / step).floor();
    if (week < 0 || week >= weeks || day < 0 || day >= 7) return null;
    final inCellX = x - week * step;
    final inCellY = y - day * step;
    if (inCellX > layout.cellSize || inCellY > layout.cellSize) return null;
    return (week, day);
  }

  @override
  Widget build(BuildContext context) {
    assert(cells.length == weeks * 7);
    final scheme = Theme.of(context).colorScheme;
    final labelColor = scheme.brightness == Brightness.dark
        ? scheme.onSurfaceVariant
        : AppColors.neutral60;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: labelColor,
          fontSize: 9,
          height: 1,
        );
    final monthLabels = _monthLabelsForWeeks();
    final weekdayLabels =
        showAllWeekdayLabels ? _fullWeekdayLabels : _sparseWeekdayLabels;
    final totalEvents = cells.fold<int>(0, (sum, count) => sum + count);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : HeatmapLayout.heightForWidth(
                width: width,
                weeks: weeks,
                gap: gap,
                dayLabelWidth: dayLabelWidth,
                monthLabelHeight: monthLabelHeight,
              );

        final layout = fixedCellSize != null
            ? HeatmapLayout.forFixedCell(
                cellSize: fixedCellSize!,
                weeks: weeks,
                gap: gap,
                monthLabelHeight: monthLabelHeight,
              )
            : HeatmapLayout.forConstraints(
                width: width,
                weeks: weeks,
                maxHeight: maxHeight,
                gap: gap,
                dayLabelWidth: dayLabelWidth,
                monthLabelHeight: monthLabelHeight,
              );
        if (layout == null) return const SizedBox.shrink();

        final cell = layout.cellSize;
        final contentWidth = fixedCellSize != null
            ? dayLabelWidth + HeatmapLayout.dayLabelGap + layout.gridWidth
            : width;

        Widget grid = SizedBox(
          width: contentWidth,
          height: layout.totalHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var week = 0; week < weeks; week++)
                if (monthLabels[week] != null)
                  Positioned(
                    left: dayLabelWidth +
                        HeatmapLayout.dayLabelGap +
                        week * (cell + gap),
                    top: 0,
                    width: cell * 3 + gap * 2,
                    height: monthLabelHeight,
                    child: Text(
                      monthLabels[week]!,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
              Positioned(
                top: monthLabelHeight + HeatmapLayout.monthToGridGap,
                left: 0,
                right: 0,
                height: layout.gridHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: dayLabelWidth,
                      height: layout.gridHeight,
                      child: Stack(
                        children: [
                          for (var day = 0; day < 7; day++)
                            if (weekdayLabels[day].isNotEmpty)
                              Positioned(
                                top: day * (cell + gap),
                                left: 0,
                                height: cell,
                                width: dayLabelWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    weekdayLabels[day],
                                    style: labelStyle,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(width: HeatmapLayout.dayLabelGap),
                    CustomPaint(
                      size: Size(layout.gridWidth, layout.gridHeight),
                      painter: _HeatmapPainter(
                        cells: cells,
                        weeks: weeks,
                        rangeStart: rangeStart,
                        cell: cell,
                        gap: gap,
                        scheme: scheme,
                        showDayNumbers: showDayNumbers,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (onCellTap != null) {
          grid = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final hit = _cellAt(details.localPosition, layout);
              if (hit == null) return;
              final (week, day) = hit;
              final index = week * 7 + day;
              final date = rangeStart.add(Duration(days: index));
              onCellTap!(date, cells[index]);
            },
            child: grid,
          );
        }

        return Semantics(
          label: semanticsLabel ??
              'Actividad de las últimas $weeks semanas, $totalEvents registros',
          child: grid,
        );
      },
    );
  }
}

/// Formats a heatmap cell tooltip: "12 Jul · 3 registros" / "Sin actividad".
String heatmapCellTooltip(DateTime day, int count) {
  final month = ActivityHeatmap._monthLabels[day.month - 1];
  final dateLabel = '${day.day} $month';
  if (count <= 0) return '$dateLabel · Sin actividad';
  final noun = count == 1 ? 'registro' : 'registros';
  return '$dateLabel · $count $noun';
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.cells,
    required this.weeks,
    required this.rangeStart,
    required this.cell,
    required this.gap,
    required this.scheme,
    required this.showDayNumbers,
  });

  final List<int> cells;
  final int weeks;
  final DateTime rangeStart;
  final double cell;
  final double gap;
  final ColorScheme scheme;
  final bool showDayNumbers;

  /// Empty / pale-green cells keep a soft gray label; stronger fills use white.
  static Color _labelColorFor(int count, ColorScheme scheme) {
    if (scheme.brightness == Brightness.dark) {
      if (count <= 1) return scheme.onSurfaceVariant;
      return count < 30 ? AppColors.white : AppColors.neutral100;
    }
    return count <= 1 ? AppColors.neutral60 : AppColors.white;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cell <= 0) return;
    // Soft corner on each cell; scales with size, stays subtle.
    final radius = Radius.circular((cell * 0.25).clamp(2.0, 5.0));
    final fontSize = (cell * 0.42).clamp(6.0, 12.0);
    for (var week = 0; week < weeks; week++) {
      for (var day = 0; day < 7; day++) {
        final index = week * 7 + day;
        final count = cells[index];
        final bg = ActivityHeatmap.colorForCount(count, scheme);
        final left = week * (cell + gap);
        final top = day * (cell + gap);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cell, cell),
          radius,
        );
        canvas.drawRRect(rect, Paint()..color = bg);

        if (!showDayNumbers) continue;

        final date = rangeStart.add(Duration(days: index));
        final tp = TextPainter(
          text: TextSpan(
            text: '${date.day}',
            style: TextStyle(
              color: _labelColorFor(count, scheme),
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: cell);
        tp.paint(
          canvas,
          Offset(
            left + (cell - tp.width) / 2,
            top + (cell - tp.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.cells != cells ||
        oldDelegate.weeks != weeks ||
        oldDelegate.rangeStart != rangeStart ||
        oldDelegate.cell != cell ||
        oldDelegate.gap != gap ||
        oldDelegate.scheme != scheme ||
        oldDelegate.showDayNumbers != showDayNumbers;
  }
}
