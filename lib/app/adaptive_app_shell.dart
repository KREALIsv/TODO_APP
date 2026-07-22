import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/layout/adaptive_breakpoints.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/domain/note_item.dart';
import '../features/notes/domain/notes_filter.dart';
import '../features/profile/presentation/profile_panel.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/widgets/list_background_layer.dart';
import '../features/shell/presentation/desktop_context_panel.dart';
import '../features/shell/presentation/desktop_panel_state.dart';

/// Root shell: mobile stack navigation or multi-column desktop layout.
class AdaptiveAppShell extends StatefulWidget {
  const AdaptiveAppShell({
    super.key,
    this.repository,
    this.settings,
  });

  final NotesRepository? repository;
  final SettingsRepository? settings;

  @override
  State<AdaptiveAppShell> createState() => _AdaptiveAppShellState();
}

class _AdaptiveAppShellState extends State<AdaptiveAppShell> {
  NotesFilter _activeFilter = NotesFilter.all;
  DesktopPanelView _panelView = DesktopPanelView.summary;
  String? _editorItemId;
  NoteType _editorInitialType = NoteType.note;
  VoidCallback? _resetHomeDay;

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;
  SettingsRepository get _settings =>
      widget.settings ?? SettingsRepository.instance;

  String? get _selectedNoteId => _panelView == DesktopPanelView.editor
      ? _editorItemId
      : null;

  void _onFilterSelected(NotesFilter filter) {
    setState(() => _activeFilter = filter);
  }

  void _openNoteEditor(NoteEditorRequest request) {
    setState(() {
      _panelView = DesktopPanelView.editor;
      _editorItemId = request.item?.id;
      _editorInitialType = request.initialType;
    });
  }

  void _closeEditorPanel() {
    setState(() {
      _panelView = DesktopPanelView.summary;
      _editorItemId = null;
    });
  }

  void _onEditorSaved(String id) {
    setState(() => _editorItemId = id);
  }

  void _openSettings({required AdaptiveLayout layout}) {
    if (layout == AdaptiveLayout.expanded) {
      setState(() => _panelView = DesktopPanelView.settings);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          repository: _repo,
          settings: _settings,
          onResetSelectedDay: _resetHomeDay,
        ),
      ),
    );
  }

  void _closeSettingsPanel() {
    setState(() => _panelView = DesktopPanelView.summary);
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openResetFromUrl());
    }
  }

  void _openResetFromUrl() {
    if (!mounted) return;
    final token = Uri.base.queryParameters['wodo_reset']?.trim();
    if (token == null || token.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordScreen(token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdaptiveBreakpoints.layoutForWidth(constraints.maxWidth);
        final useMasterDetail = layout == AdaptiveLayout.expanded;

        if (layout == AdaptiveLayout.compact) {
          return HomeScreen(
            repository: _repo,
            activeFilter: _activeFilter,
            onFilterChanged: _onFilterSelected,
          );
        }

        if (!useMasterDetail && _panelView != DesktopPanelView.summary) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _panelView = DesktopPanelView.summary;
              _editorItemId = null;
            });
          });
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListBackgroundScaffoldBody(
            settings: _settings,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: AdaptiveBreakpoints.profileSidebarWidth,
                  child: ProfilePanel(
                    repository: _repo,
                    settings: _settings,
                    density: ProfilePanelDensity.sidebar,
                    onFilterSelected: _onFilterSelected,
                    onOpenSettings: () => _openSettings(layout: layout),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: HomeScreen(
                    repository: _repo,
                    activeFilter: _activeFilter,
                    onFilterChanged: _onFilterSelected,
                    embeddedInShell: true,
                    onOpenSettings: () => _openSettings(layout: layout),
                    onRegisterDayReset: (callback) => _resetHomeDay = callback,
                    onOpenNoteEditor:
                        useMasterDetail ? _openNoteEditor : null,
                    selectedNoteId:
                        useMasterDetail ? _selectedNoteId : null,
                  ),
                ),
                if (useMasterDetail) ...[
                  const VerticalDivider(width: 1, thickness: 1),
                  SizedBox(
                    width: AdaptiveBreakpoints.contextPanelWidth,
                    child: DesktopContextPanel(
                      repository: _repo,
                      settings: _settings,
                      view: _panelView,
                      editorItemId: _editorItemId,
                      editorInitialType: _editorInitialType,
                      onCloseSettings: _closeSettingsPanel,
                      onCloseEditor: _closeEditorPanel,
                      onEditorSaved: _onEditorSaved,
                      onResetSelectedDay: _resetHomeDay,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
