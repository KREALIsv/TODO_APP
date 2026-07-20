import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/presentation/background_palette.dart';
import '../global/constants/constants.dart';

class TodosApp extends StatelessWidget {
  const TodosApp({super.key, this.settings});

  final SettingsRepository? settings;

  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final lightAccent =
            _settings.listBackground.resolveAccent(Brightness.light);
        final darkAccent =
            _settings.listBackground.resolveAccent(Brightness.dark);

        return MaterialApp(
          title: Config.title,
          theme: BackgroundPalette.fromAccent(lightAccent, Brightness.light)
              .tint(AppTheme.light()),
          darkTheme: BackgroundPalette.fromAccent(darkAccent, Brightness.dark)
              .tint(AppTheme.dark()),
          themeMode: _settings.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
