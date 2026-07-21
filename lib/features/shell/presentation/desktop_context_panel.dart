import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/theme/app_surface.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/activity_stats.dart';
import '../../notes/domain/note_item.dart';
import '../../notes/presentation/note_editor_screen.dart';
import '../../notes/presentation/widgets/monthly_activity_bars.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../global/widgets/activity_stat_card.dart';
import 'desktop_column_header.dart';
import 'desktop_panel_state.dart';

/// Right-hand contextual panel on wide desktop layouts.
class DesktopContextPanel extends StatelessWidget {
  const DesktopContextPanel({
    super.key,
    this.repository,
    this.settings,
    required this.view,
    required this.editorItemId,
    required this.editorInitialType,
    required this.onCloseSettings,
    required this.onCloseEditor,
    required this.onEditorSaved,
    this.onResetSelectedDay,
  });

  final NotesRepository? repository;
  final SettingsRepository? settings;
  final DesktopPanelView view;
  final String? editorItemId;
  final NoteType editorInitialType;
  final VoidCallback onCloseSettings;
  final VoidCallback onCloseEditor;
  final ValueChanged<String> onEditorSaved;
  final VoidCallback? onResetSelectedDay;

  NotesRepository get _repo => repository ?? NotesRepository.instance;
  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  String get _headerTitle => switch (view) {
        DesktopPanelView.settings => 'Ajustes',
        DesktopPanelView.editor => 'Editor',
        DesktopPanelView.summary => 'Resumen',
      };

  VoidCallback? get _headerBack => switch (view) {
        DesktopPanelView.settings => onCloseSettings,
        DesktopPanelView.editor => onCloseEditor,
        DesktopPanelView.summary => null,
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view != DesktopPanelView.editor)
            DesktopColumnHeader(
              title: _headerTitle,
              leading: _headerBack != null
                  ? IconButton(
                      tooltip: 'Volver',
                      onPressed: _headerBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
            ),
          Expanded(
            child: switch (view) {
              DesktopPanelView.settings => SettingsScreen(
                  repository: _repo,
                  settings: _settings,
                  onResetSelectedDay: onResetSelectedDay,
                  embedded: true,
                ),
              DesktopPanelView.editor => _EditorBody(
                  repository: _repo,
                  itemId: editorItemId,
                  initialType: editorInitialType,
                  onClose: onCloseEditor,
                  onSaved: onEditorSaved,
                ),
              DesktopPanelView.summary => _SummaryBody(
                  repository: _repo,
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.repository,
    required this.itemId,
    required this.initialType,
    required this.onClose,
    required this.onSaved,
  });

  final NotesRepository repository;
  final String? itemId;
  final NoteType initialType;
  final VoidCallback onClose;
  final ValueChanged<String> onSaved;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Map>>(
      valueListenable: repository.listenable(),
      builder: (context, box, _) {
        final item = itemId != null ? repository.getById(itemId!) : null;

        if (itemId != null && item == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onClose());
          return const Center(
            child: Text('La nota ya no existe'),
          );
        }

        return NoteEditorScreen(
          key: ValueKey(itemId ?? 'create-$initialType'),
          item: item,
          initialType: initialType,
          repository: repository,
          embedded: true,
          onClose: onClose,
          onSaved: onSaved,
        );
      },
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.repository,
  });

  final NotesRepository repository;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<Box<Map>>(
      valueListenable: repository.listenable(),
      builder: (context, box, _) {
        final items = repository.getAll();
        final metrics = activityMetricsFrom(items);
        final stats = ActivityStats.fromNotes(items, weeks: 1);
        final archivedCount = repository.getArchived().length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Selecciona una nota o tarea para editarla aquí.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Actividad mensual',
              style: textTheme.titleSmall?.copyWith(
                color: AppSurface.secondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            MonthlyActivityBars(
              bars: monthlyEventBars(eventCounts: metrics.eventCounts),
            ),
            const SizedBox(height: 20),
            Text(
              'Esta semana',
              style: textTheme.titleSmall?.copyWith(
                color: AppSurface.secondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ActivityStatCard(
              icon: Icons.local_fire_department_outlined,
              label: 'Racha actual',
              value: stats.streak == 1 ? '1 día' : '${stats.streak} días',
            ),
            const SizedBox(height: 8),
            ActivityStatCard(
              icon: Icons.archive_outlined,
              label: 'Archivadas',
              value: '$archivedCount',
            ),
          ],
        );
      },
    );
  }
}
