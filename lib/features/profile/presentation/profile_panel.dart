import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/activity_stat_card.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/activity_stats.dart';
import '../../notes/domain/notes_filter.dart';
import '../../notes/presentation/widgets/activity_heatmap.dart';
import '../../notes/presentation/widgets/monthly_activity_bars.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/widgets/list_background_layer.dart';
import '../../shell/presentation/desktop_column_header.dart';

enum ProfilePanelDensity {
  /// Full-width fluid layout (mobile profile screen).
  fullScreen,

  /// Fixed cell size, scroll horizontally for more weeks (desktop sidebar).
  sidebar,
}

/// Profile stats and navigation — used in the profile route and desktop sidebar.
class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    super.key,
    this.repository,
    this.settings,
    this.density = ProfilePanelDensity.fullScreen,
    this.onFilterSelected,
    this.onOpenSettings,
  });

  final NotesRepository? repository;
  final SettingsRepository? settings;
  final ProfilePanelDensity density;
  final ValueChanged<NotesFilter>? onFilterSelected;
  final VoidCallback? onOpenSettings;

  NotesRepository get _repo => repository ?? NotesRepository.instance;
  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  static const heatmapGap = 3.0;
  static const minCellWithNumbers = 14.0;
  static const minCellCompact = 12.0;
  static const maxCellWithNumbers = 14.0;
  static const maxCellCompact = 12.0;
  static const sidebarWeeks = 26;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSidebar = density == ProfilePanelDensity.sidebar;

    final scrollContent = SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          return ValueListenableBuilder<Box<Map>>(
            valueListenable: _repo.listenable(),
            builder: (context, box, child) {
              final items = _repo.getAll();
              final counts = contentCounts(items);
              final metrics = activityMetricsFrom(items);
              final baseStats = ActivityStats.fromNotes(items, weeks: 1);
              final isEmpty = items.isEmpty;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  isSidebar ? 12 : 16,
                  isSidebar ? 12 : 16,
                  isSidebar ? 12 : 16,
                  24,
                ),
                children: [
                  ProfileActivityHero(
                    textTheme: textTheme,
                    eventCounts: metrics.eventCounts,
                    isEmpty: isEmpty,
                    showDayNumbers: _settings.showHeatmapDayNumbers,
                    density: density,
                  ),
                  const SizedBox(height: 16),
                  ProfileSecondaryStats(
                    bestStreak: baseStats.bestStreak,
                    activeDayCount: baseStats.activeDayCount,
                  ),
                  if (!isSidebar) ...[
                    const SizedBox(height: 16),
                    MonthlyActivityBars(
                      bars: monthlyEventBars(
                        eventCounts: metrics.eventCounts,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ProfileContentRows(
                    textTheme: textTheme,
                    noteCount: counts.notes,
                    taskCount: counts.tasks,
                    pendingTasks: counts.pendingTasks,
                    onFilterSelected: onFilterSelected,
                  ),
                  if (onOpenSettings != null) ...[
                    const SizedBox(height: 12),
                    ProfileSettingsAccessRow(
                      textTheme: textTheme,
                      onTap: onOpenSettings!,
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );

    if (isSidebar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesktopColumnHeader(title: 'Perfil'),
          Expanded(child: scrollContent),
        ],
      );
    }

    return ListBackgroundScaffoldBody(
      settings: _settings,
      child: scrollContent,
    );
  }
}

class ProfileActivityHero extends StatelessWidget {
  const ProfileActivityHero({
    super.key,
    required this.textTheme,
    required this.eventCounts,
    required this.isEmpty,
    required this.showDayNumbers,
    required this.density,
  });

  final TextTheme textTheme;
  final Map<DateTime, int> eventCounts;
  final bool isEmpty;
  final bool showDayNumbers;
  final ProfilePanelDensity density;

  static const _dayLabelWidth = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: AppSurface.cardDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSidebar = density == ProfilePanelDensity.sidebar;
          final minCell = showDayNumbers
              ? ProfilePanel.minCellWithNumbers
              : ProfilePanel.minCellCompact;
          final maxCell = showDayNumbers
              ? ProfilePanel.maxCellWithNumbers
              : ProfilePanel.maxCellCompact;

          late final int weeks;
          late final double? fixedCellSize;

          if (isSidebar) {
            fixedCellSize = maxCell;
            weeks = ProfilePanel.sidebarWeeks;
          } else {
            fixedCellSize = null;
            weeks = HeatmapLayout.weeksForMinCell(
              width: constraints.maxWidth,
              gap: ProfilePanel.heatmapGap,
              minCell: minCell,
              maxCellSize: maxCell,
              preferredMax: showDayNumbers ? 12 : 15,
              preferredMid: showDayNumbers ? 10 : 12,
              dayLabelWidth: _dayLabelWidth,
            );
          }

          final cells = weekCounts(counts: eventCounts, weeks: weeks);
          final rangeStart = heatmapRangeStart(weeks: weeks);
          final totalEvents = cells.fold<int>(0, (sum, count) => sum + count);

          final layout = fixedCellSize != null
              ? HeatmapLayout.forFixedCell(
                  cellSize: fixedCellSize,
                  weeks: weeks,
                  gap: ProfilePanel.heatmapGap,
                )
              : HeatmapLayout.forConstraints(
                  width: constraints.maxWidth,
                  weeks: weeks,
                  gap: ProfilePanel.heatmapGap,
                  dayLabelWidth: _dayLabelWidth,
                  maxCellSize: maxCell,
                );
          final height = layout?.totalHeight ??
              ActivityHeatmap.heightForWidth(
                width: constraints.maxWidth,
                weeks: weeks,
                gap: ProfilePanel.heatmapGap,
                dayLabelWidth: _dayLabelWidth,
              );

          final gridNaturalWidth = fixedCellSize != null
              ? _dayLabelWidth +
                  HeatmapLayout.dayLabelGap +
                  (layout?.gridWidth ?? 0)
              : constraints.maxWidth;

          Widget heatmap = SizedBox(
            height: height,
            child: ActivityHeatmap(
              cells: cells,
              weeks: weeks,
              rangeStart: rangeStart,
              gap: ProfilePanel.heatmapGap,
              dayLabelWidth: _dayLabelWidth,
              showAllWeekdayLabels: true,
              showDayNumbers: showDayNumbers,
              fixedCellSize: fixedCellSize,
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
          );

          if (isSidebar && gridNaturalWidth > constraints.maxWidth) {
            heatmap = _HeatmapHorizontalScroll(
              gridWidth: gridNaturalWidth,
              child: heatmap,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heatmap,
              const SizedBox(height: 12),
              ProfileHeatmapLegend(totalEvents: totalEvents),
              if (isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Captura tu primera nota para empezar a ver actividad.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppSurface.secondary(context),
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

/// Horizontal scrollbar for the sidebar heatmap — owns its [ScrollController]
/// so it does not rely on [PrimaryScrollController] (invalid on web/desktop).
class _HeatmapHorizontalScroll extends StatefulWidget {
  const _HeatmapHorizontalScroll({
    required this.gridWidth,
    required this.child,
  });

  final double gridWidth;
  final Widget child;

  @override
  State<_HeatmapHorizontalScroll> createState() =>
      _HeatmapHorizontalScrollState();
}

class _HeatmapHorizontalScrollState extends State<_HeatmapHorizontalScroll> {
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        primary: false,
        child: SizedBox(
          width: widget.gridWidth,
          child: widget.child,
        ),
      ),
    );
  }
}

class ProfileSecondaryStats extends StatelessWidget {
  const ProfileSecondaryStats({
    super.key,
    required this.bestStreak,
    required this.activeDayCount,
  });

  final int bestStreak;
  final int activeDayCount;

  @override
  Widget build(BuildContext context) {
    final bestLabel = bestStreak == 1 ? '1 día' : '$bestStreak días';

    return Row(
      children: [
        Expanded(
          child: ActivityStatCard(
            value: bestLabel,
            label: 'Mejor racha',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ActivityStatCard(
            value: '$activeDayCount',
            label: 'Días activos',
          ),
        ),
      ],
    );
  }
}

class ProfileContentRows extends StatelessWidget {
  const ProfileContentRows({
    super.key,
    required this.textTheme,
    required this.noteCount,
    required this.taskCount,
    required this.pendingTasks,
    this.onFilterSelected,
  });

  final TextTheme textTheme;
  final int noteCount;
  final int taskCount;
  final int pendingTasks;
  final ValueChanged<NotesFilter>? onFilterSelected;

  void _selectFilter(BuildContext context, NotesFilter filter) {
    if (onFilterSelected != null) {
      onFilterSelected!(filter);
      return;
    }
    Navigator.of(context).pop(filter);
  }

  @override
  Widget build(BuildContext context) {
    final pendingLabel = pendingTasks == 1
        ? '1 pendiente'
        : '$pendingTasks pendientes';
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: AppSurface.cardDecoration(context),
      child: Column(
        children: [
          ProfileContentRow(
            textTheme: textTheme,
            icon: Icons.sticky_note_2_outlined,
            title: 'Notas',
            trailing: '$noteCount',
            accent: accent,
            onTap: () => _selectFilter(context, NotesFilter.notes),
          ),
          Divider(height: 1, color: AppSurface.divider(context)),
          ProfileContentRow(
            textTheme: textTheme,
            icon: Icons.check_circle_outline,
            title: 'Tareas',
            trailing: pendingTasks > 0
                ? '$taskCount · $pendingLabel'
                : '$taskCount',
            accent: accent,
            onTap: () => _selectFilter(context, NotesFilter.tasks),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsAccessRow extends StatelessWidget {
  const ProfileSettingsAccessRow({
    super.key,
    required this.textTheme,
    required this.onTap,
  });

  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: AppSurface.cardDecoration(context),
      child: ProfileContentRow(
        textTheme: textTheme,
        icon: Icons.settings_outlined,
        title: 'Ajustes',
        accent: accent,
        onTap: onTap,
      ),
    );
  }
}

class ProfileContentRow extends StatelessWidget {
  const ProfileContentRow({
    super.key,
    required this.textTheme,
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
    required this.accent,
  });

  final TextTheme textTheme;
  final IconData icon;
  final String title;
  final String? trailing;
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
                  color: AppSurface.title(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppSurface.mutedIcon(context),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileHeatmapLegend extends StatelessWidget {
  const ProfileHeatmapLegend({super.key, required this.totalEvents});

  final int totalEvents;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppSurface.secondary(context),
        );
    final totalLabel = totalEvents == 1
        ? '1 registro'
        : '$totalEvents registros';

    return Row(
      children: [
        Flexible(
          child: Text(
            totalLabel,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text('Menos', style: style),
        const SizedBox(width: 6),
        for (final count in ActivityHeatmap.legendSampleCounts) ...[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: ActivityHeatmap.colorForCount(
                count,
                Theme.of(context).colorScheme,
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
