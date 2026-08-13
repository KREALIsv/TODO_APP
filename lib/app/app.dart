import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'adaptive_app_shell.dart';
import '../core/web/web_history_navigation.dart';
import '../features/app_lock/app_lock_controller.dart';
import '../features/app_lock/presentation/app_lock_screens.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/presentation/background_palette.dart';
import '../global/constants/constants.dart';
import '../global/widgets/account_switch_gate_listener.dart';
import '../global/widgets/session_expiry_listener.dart';
import '../global/widgets/sync_status_banner.dart';

class TodosApp extends StatefulWidget {
  const TodosApp({super.key, this.settings});

  final SettingsRepository? settings;

  @override
  State<TodosApp> createState() => _TodosAppState();
}

class _TodosAppState extends State<TodosApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  SettingsRepository get _settings =>
      widget.settings ?? SettingsRepository.instance;

  @override
  void initState() {
    super.initState();
    WebHistoryNavigation.install(_navigatorKey);
    AppLockController.instance.attach();
  }

  @override
  void dispose() {
    AppLockController.instance.detach();
    WebHistoryNavigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final lightAccent = _settings.listBackground.resolveAccent(
          Brightness.light,
        );
        final darkAccent = _settings.listBackground.resolveAccent(
          Brightness.dark,
        );

        return MaterialApp(
          title: Config.title,
          navigatorKey: _navigatorKey,
          navigatorObservers: [WebHistoryNavigatorObserver()],
          theme: BackgroundPalette.fromAccent(
            lightAccent,
            Brightness.light,
          ).tint(AppTheme.light()),
          darkTheme: BackgroundPalette.fromAccent(
            darkAccent,
            Brightness.dark,
          ).tint(AppTheme.dark()),
          themeMode: _settings.themeMode,
          builder: (context, child) {
            return ListenableBuilder(
              listenable: AppLockController.instance,
              builder: (context, _) {
                final lock = AppLockController.instance;
                return AccountSwitchGateListener(
                  navigatorKey: _navigatorKey,
                  child: SessionExpiryListener(
                    navigatorKey: _navigatorKey,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SyncStatusBanner(
                          child: child ?? const SizedBox.shrink(),
                        ),
                        if (lock.shouldShowLock && lock.contentReady)
                          const Positioned.fill(
                            child: Material(child: AppLockUnlockScreen()),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          home: ListenableBuilder(
            listenable: AppLockController.instance,
            builder: (context, _) {
              if (!AppLockController.instance.contentReady) {
                return const AppLockUnlockScreen();
              }
              return const AdaptiveAppShell();
            },
          ),
        );
      },
    );
  }
}
