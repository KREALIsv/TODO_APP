import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../notes/data/notes_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_screen.dart';
import 'profile_panel.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.repository,
    this.settings,
    this.onResetSelectedDay,
  });

  final NotesRepository? repository;
  final SettingsRepository? settings;

  /// Forwards to [SettingsScreen] so "Ir a hoy" can restore the home day.
  final VoidCallback? onResetSelectedDay;

  NotesRepository get _repo => repository ?? NotesRepository.instance;
  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  Future<void> _openSettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          repository: _repo,
          settings: _settings,
          onResetSelectedDay: onResetSelectedDay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ProfilePanel(
        repository: _repo,
        settings: _settings,
        density: ProfilePanelDensity.fullScreen,
        onOpenSettings: () => _openSettings(context),
      ),
    );
  }
}
