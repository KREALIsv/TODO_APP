import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../domain/activity_stats.dart';
import 'activity_heatmap.dart';

/// Card with thin vertical bars comparing write-activity volume across months.
class MonthlyActivityBars extends StatelessWidget {
  const MonthlyActivityBars({
    super.key,
    required this.bars,
    this.chartHeight = 72,
    this.barWidth = 14,
  });

  final List<MonthActivityBar> bars;
  final double chartHeight;

  /// Visual thickness of each pill bar (centered in its column).
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final maxCount = bars.fold<int>(0, (m, b) => b.count > m ? b.count : m);
    final total = bars.fold<int>(0, (sum, b) => sum + b.count);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: AppSurface.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registros mensuales',
            style: textTheme.labelLarge?.copyWith(
              color: AppSurface.title(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: total == 0
                ? 'Sin registros mensuales'
                : 'Registros mensuales, $total en los últimos ${bars.length} meses',
            child: SizedBox(
              height: chartHeight + 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bar in bars)
                    Expanded(
                      child: _MonthBarColumn(
                        bar: bar,
                        maxCount: maxCount,
                        chartHeight: chartHeight,
                        barWidth: barWidth,
                        scheme: scheme,
                        labelStyle: textTheme.labelSmall?.copyWith(
                          color: AppSurface.secondary(context),
                          fontSize: 10,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBarColumn extends StatelessWidget {
  const _MonthBarColumn({
    required this.bar,
    required this.maxCount,
    required this.chartHeight,
    required this.barWidth,
    required this.scheme,
    required this.labelStyle,
  });

  final MonthActivityBar bar;
  final int maxCount;
  final double chartHeight;
  final double barWidth;
  final ColorScheme scheme;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount <= 0 ? 0.0 : bar.count / maxCount;
    final height = bar.count <= 0
        ? 6.0
        : (6.0 + (chartHeight - 6.0) * ratio).clamp(6.0, chartHeight);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: bar.count == 1
              ? '1 registro'
              : '${bar.count} registros',
          child: SizedBox(
            height: chartHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: ActivityHeatmap.colorForIntensity(ratio, scheme),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(bar.label, style: labelStyle, textAlign: TextAlign.center),
      ],
    );
  }
}
