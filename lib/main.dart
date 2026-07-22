import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app/app.dart';
import 'core/theme/theme.dart';
import 'core/web/boot_ready.dart';
import 'features/auth/data/auth_session_repository.dart';
import 'features/notes/data/attachments_repository.dart';
import 'features/notes/data/day_entries_repository.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/tags_repository.dart';
import 'features/notes/data/task_reminders_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/sync/data/device_identity.dart';
import 'features/sync/data/sync_service.dart';
import 'global/widgets/app_boot_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Paint immediately: on web the HTML splash (logo) stays until
  // [notifyWebAppReady]; on native we show the same branding in Flutter.
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  Object? _error;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      HiveLogger.level = HiveLoggerLevel.warn;
      await Hive.initFlutter();
      await Future.wait([
        NotesRepository.instance.init(),
        DayEntriesRepository.instance.init(),
        TagsRepository.instance.init(),
        AttachmentsRepository.instance.init(),
        SettingsRepository.instance.init(),
        AuthSessionRepository.instance.init(),
        DeviceIdentity.instance.init(),
      ]);
      await SyncService.instance.init();
      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyWebAppReady();
      });
      unawaited(_postBootstrap());
    } catch (e, st) {
      debugPrint('App bootstrap failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = e);
      notifyWebAppReady();
    }
  }

  Future<void> _postBootstrap() async {
    try {
      await TagsRepository.instance.ensureTags(
        NotesRepository.instance.getAllTags(),
      );
      await TaskRemindersService.instance.init();
      await NotesRepository.instance.syncAllReminders();
    } catch (e, st) {
      debugPrint('Post-bootstrap skipped: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const TodosApp();

    return MaterialApp(
      title: 'WODO',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _error == null
          ? (kIsWeb
              ? const SizedBox.shrink()
              : const AppBootSplash())
          : _BootstrapErrorScreen(
              error: _error!,
              onRetry: () {
                setState(() {
                  _error = null;
                  _ready = false;
                });
                _bootstrap();
              },
            ),
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 40, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'No se pudo abrir WODO',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? 'Prueba de nuevo. Si sigue en blanco, borra los datos '
                            'del sitio app.wodo.app en el navegador y recarga.'
                        : 'Prueba de nuevo. Si el problema continúa, reinicia la app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
