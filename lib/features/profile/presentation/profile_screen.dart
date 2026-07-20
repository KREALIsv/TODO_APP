import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../global/themes/app_colors.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/activity_stats.dart';
import '../../notes/domain/notes_filter.dart';
import '../../notes/presentation/widgets/activity_heatmap.dart';
import '../../notes/presentation/widgets/monthly_activity_bars.dart';
import '../../settings/presentation/widgets/list_background_layer.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.repository});

  final NotesRepository? repository;

  NotesRepository get _repo => repository ?? NotesRepository.instance;

  static const heatmapGap = 3.0;
  static const minCell = 12.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: isDark ? const Color(0xFF1C2128) : AppColors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: isDark ? const Color(0xFFE6EDF3) : AppColors.neutral100,
      ),
      body: ListBackgroundScaffoldBody(
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<Box<Map>>(
            valueListenable: _repo.listenable(),
            builder: (context, box, child) {
              final items = _repo.getAll();
              final counts = contentCounts(items);
              final metrics = activityMetricsFrom(items);
              final baseStats = ActivityStats.fromNotes(items, weeks: 1);
              final isEmpty = items.isEmpty;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _ActivityHero(
                    textTheme: textTheme,
                    eventCounts: metrics.eventCounts,
                    isEmpty: isEmpty,
                  ),
                  const SizedBox(height: 16),
                  _SecondaryStats(
                    textTheme: textTheme,
                    bestStreak: baseStats.bestStreak,
                    activeDayCount: baseStats.activeDayCount,
                  ),
                  const SizedBox(height: 16),
                  MonthlyActivityBars(
                    bars: monthlyEventBars(eventCounts: metrics.eventCounts),
                  ),
                  const SizedBox(height: 20),
                  _ContentRows(
                    textTheme: textTheme,
                    noteCount: counts.notes,
                    taskCount: counts.tasks,
                    pendingTasks: counts.pendingTasks,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActivityHero extends StatelessWidget {
  const _ActivityHero({
    required this.textTheme,
    required this.eventCounts,
    required this.isEmpty,
  });

  final TextTheme textTheme;
  final Map<DateTime, int> eventCounts;
  final bool isEmpty;

  static const _dayLabelWidth = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final weeks = HeatmapLayout.weeksForMinCell(
            width: constraints.maxWidth,
            gap: ProfileScreen.heatmapGap,
            minCell: ProfileScreen.minCell,
            preferredMax: 15,
            preferredMid: 12,
            dayLabelWidth: _dayLabelWidth,
          );
          final cells = weekCounts(
            counts: eventCounts,
            weeks: weeks,
          );
          final rangeStart = heatmapRangeStart(weeks: weeks);
          final totalEvents = cells.fold<int>(0, (sum, count) => sum + count);
          final height = ActivityHeatmap.heightForWidth(
            width: constraints.maxWidth,
            weeks: weeks,
            gap: ProfileScreen.heatmapGap,
            dayLabelWidth: _dayLabelWidth,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                child: ActivityHeatmap(
                  cells: cells,
                  weeks: weeks,
                  rangeStart: rangeStart,
                  gap: ProfileScreen.heatmapGap,
                  dayLabelWidth: _dayLabelWidth,
                  showAllWeekdayLabels: true,
                  semanticsLabel:
                      'Actividad de las últimas $weeks semanas, $totalEvents registros',
                  onCellTap: (day, count) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(heatmapCellTooltip(day, count)),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _HeatmapLegend(totalEvents: totalEvents),
              if (isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Captura tu primera nota para empezar a ver actividad.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SecondaryStats extends StatelessWidget {
  const _SecondaryStats({
    required this.textTheme,
    required this.bestStreak,
    required this.activeDayCount,
  });

  final TextTheme textTheme;
  final int bestStreak;
  final int activeDayCount;

  @override
  Widget build(BuildContext context) {
    final bestLabel = bestStreak == 1 ? '1 día' : '$bestStreak días';

    return Row(
      children: [
        Expanded(
          child: _CompactStat(
            textTheme: textTheme,
            value: bestLabel,
            label: 'Mejor racha',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CompactStat(
            textTheme: textTheme,
            value: '$activeDayCount',
            label: 'Días activos',
          ),
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.textTheme,
    required this.value,
    required this.label,
  });

  final TextTheme textTheme;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.neutral100,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.neutral60,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentRows extends StatelessWidget {
  const _ContentRows({
    required this.textTheme,
    required this.noteCount,
    required this.taskCount,
    required this.pendingTasks,
  });

  final TextTheme textTheme;
  final int noteCount;
  final int taskCount;
  final int pendingTasks;

  @override
  Widget build(BuildContext context) {
    final pendingLabel = pendingTasks == 1
        ? '1 pendiente'
        : '$pendingTasks pendientes';
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral20),
      ),
      child: Column(
        children: [
          _ContentRow(
            textTheme: textTheme,
            icon: Icons.sticky_note_2_outlined,
            title: 'Notas',
            trailing: '$noteCount',
            accent: accent,
            onTap: () => Navigator.of(context).pop(NotesFilter.notes),
          ),
          const Divider(height: 1, color: AppColors.neutral20),
          _ContentRow(
            textTheme: textTheme,
            icon: Icons.check_circle_outline,
            title: 'Tareas',
            trailing: pendingTasks > 0
                ? '$taskCount · $pendingLabel'
                : '$taskCount',
            accent: accent,
            onTap: () => Navigator.of(context).pop(NotesFilter.tasks),
          ),
        ],
      ),
    );
  }
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.textTheme,
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    required this.accent,
  });

  final TextTheme textTheme;
  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.neutral100,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              trailing,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.neutral60,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.neutral40,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.totalEvents});

  final int totalEvents;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.neutral60,
        );
    final totalLabel = totalEvents == 1
        ? '1 registro'
        : '$totalEvents registros';

    return Row(
      children: [
        Text(totalLabel, style: style),
        const Spacer(),
        Text('Menos', style: style),
        const SizedBox(width: 8),
        for (final count in [0, 1, 2, 3, 5]) ...[
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: ActivityHeatmap.colorForCount(
                count,
                Theme.of(context).colorScheme,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        const SizedBox(width: 4),
        Text('Más', style: style),
      ],
    );
  }
}
