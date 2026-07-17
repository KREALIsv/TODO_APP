import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/activity_stats.dart';
import 'activity_heatmap.dart';

/// Compact streak summary + heatmap row for Home.
class ActivityStrip extends StatelessWidget {
  const ActivityStrip({
    super.key,
    required this.stats,
    this.horizontalPadding = 16,
    this.gap = 2.0,
  });

  final ActivityStats stats;
  final double horizontalPadding;
  final double gap;

  static const double headerHeight = 18;
  static const double headerGap = 6;
  static const double verticalPadding = 10; // 4 top + 6 bottom

  static double heightForWidth({
    required double width,
    required int weeks,
    double horizontalPadding = 16,
    double gap = 2.0,
  }) {
    final gridWidth =
        (width - horizontalPadding * 2).clamp(0.0, double.infinity);
    final heatmapHeight = ActivityHeatmap.heightForWidth(
      width: gridWidth,
      weeks: weeks,
      gap: gap,
    );
    return headerHeight + headerGap + heatmapHeight + verticalPadding;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final streakLabel =
        stats.streak == 1 ? '1 día' : '${stats.streak} días';

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = heightForWidth(
          width: constraints.maxWidth,
          weeks: stats.weeks,
          horizontalPadding: horizontalPadding,
          gap: gap,
        );

        return SizedBox(
          height: totalHeight,
          width: constraints.maxWidth,
          child: ClipRect(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Row(
                      children: [
                        Text(
                          streakLabel,
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.neutral80,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral40,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${stats.activeDaysThisWeek} esta semana',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.neutral60,
                              height: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: headerGap),
                  Expanded(
                    child: ActivityHeatmap(
                      cells: stats.cells,
                      weeks: stats.weeks,
                      rangeStart: stats.rangeStart,
                      gap: gap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
