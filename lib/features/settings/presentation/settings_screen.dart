import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/constants/config.dart';
import '../../../global/themes/app_colors.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../notes/data/attachments_repository.dart';
import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/data/tags_repository.dart';
import '../data/settings_repository.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/sync_service.dart';
import '../domain/list_background.dart';
import 'about_screen.dart';
import 'archived_screen.dart';
import 'data_backup.dart';
import 'fondo_picker_screen.dart';
import 'widgets/list_background_layer.dart';
import 'widgets/settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.repository,
    this.settings,
    this.onResetSelectedDay,
    this.embedded = false,
  });

  final NotesRepository? repository;
  final SettingsRepository? settings;

  /// Restores the home day selector to today, then returns to the root route.
  final VoidCallback? onResetSelectedDay;
  final bool embedded;

  NotesRepository get _repo => repository ?? NotesRepository.instance;
  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  void _goToToday(BuildContext context) {
    onResetSelectedDay?.call();
    if (!context.mounted) return;
    if (embedded) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _pickTheme(BuildContext context) async {
    final selected = await showSettingsRadioSheet<ThemeMode>(
      context: context,
      title: 'Tema',
      groupValue: _settings.themeMode,
      options: const [
        (ThemeMode.system, 'Sistema'),
        (ThemeMode.light, 'Claro'),
        (ThemeMode.dark, 'Oscuro'),
      ],
    );
    if (selected != null) {
      await _settings.setThemeMode(selected);
    }
  }

  Future<void> _pickHeatmapDayNumbers(BuildContext context) async {
    final selected = await showSettingsRadioSheet<bool>(
      context: context,
      title: 'Números en el heatmap',
      groupValue: _settings.showHeatmapDayNumbers,
      options: const [(true, 'Visibles'), (false, 'Ocultos')],
    );
    if (selected != null) {
      await _settings.setShowHeatmapDayNumbers(selected);
    }
  }

  Future<void> _openFondo(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FondoPickerScreen(settings: _settings),
      ),
    );
  }

  Future<void> _openArchived(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArchivedScreen(repository: _repo),
      ),
    );
  }

  Future<void> _openAbout(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
  }

  Future<void> _openAccount(BuildContext context) {
    return AuthFlow.openLogin(
      context,
      contextTitle: 'Sincronización multidispositivo',
      contextMessage:
          'Tus notas siguen disponibles sin conexión. Al iniciar sesión se '
          'combinarán de forma segura con tu cuenta.',
    );
  }

  Future<void> _syncNow(BuildContext context) => AuthFlow.syncNow(context);

  Future<void> _toggleDeviceSync(BuildContext context) async {
    final next = !DeviceIdentity.instance.syncEnabled;
    await DeviceIdentity.instance.setSyncEnabled(next);
    if (!context.mounted) return;
    if (next && AuthService.instance.isAuthenticated) {
      await SyncService.instance.syncNow();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next
              ? 'Sincronización activa en este dispositivo'
              : 'Sincronización pausada en este dispositivo',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      await exportNotesData(
        _repo,
        tags: TagsRepository.instance,
        dayEntries: DayEntriesRepository.instance,
        attachments: AttachmentsRepository.instance,
      );
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: 'Datos exportados',
        type: AppAlertType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo exportar: $e',
        type: AppAlertType.error,
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Importar datos',
      message: 'Esto reemplazará tus notas y tareas actuales. ¿Continuar?',
      confirmLabel: 'Continuar',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final result = await importNotesData(
        _repo,
        tags: TagsRepository.instance,
        dayEntries: DayEntriesRepository.instance,
        attachments: AttachmentsRepository.instance,
      );
      if (!context.mounted) return;
      if (result == ImportResult.cancelled) return;
      if (result == ImportResult.invalid) {
        await AppAlerts.show(
          context,
          message: 'El archivo no es válido o está corrupto.',
          type: AppAlertType.error,
        );
        return;
      }
      await AppAlerts.show(
        context,
        message: 'Datos importados',
        type: AppAlertType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo importar: $e',
        type: AppAlertType.error,
      );
    }
  }

  Future<void> _wipe(BuildContext context) async {
    final first = await AppAlerts.confirm(
      context,
      title: 'Borrar todos los datos',
      message:
          'Se eliminarán todas tus notas y tareas, incluidas las archivadas. Esta acción no se puede deshacer.',
      confirmLabel: 'Continuar',
      isDestructive: true,
    );
    if (!first || !context.mounted) return;

    final second = await AppAlerts.confirm(
      context,
      title: '¿Seguro?',
      message: 'Confirma que quieres borrar todo permanentemente.',
      confirmLabel: 'Borrar todo',
      isDestructive: true,
    );
    if (!second || !context.mounted) return;

    await resetAllAppContent(
      notes: _repo,
      tags: TagsRepository.instance,
      dayEntries: DayEntriesRepository.instance,
      attachments: AttachmentsRepository.instance,
    );
    if (!context.mounted) return;
    await AppAlerts.show(
      context,
      message: 'Todos los datos fueron eliminados',
      type: AppAlertType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final inner = ListenableBuilder(
      listenable: Listenable.merge([
        _settings,
        AuthService.instance,
        SyncService.instance,
        DeviceIdentity.instance,
      ]),
      builder: (context, _) {
        final bg = _settings.listBackground;
        final brightness = Theme.of(context).brightness;
        final accent = bg.resolveAccent(brightness);
        return ValueListenableBuilder<Box<Map>>(
          valueListenable: _repo.listenable(),
          builder: (context, box, _) {
            final archivedCount = _repo.getArchived().length;
            return ListView(
              padding: EdgeInsets.fromLTRB(16, embedded ? 8 : 16, 16, 32),
              children: _settingsSections(
                context: context,
                textTheme: textTheme,
                accent: accent,
                archivedCount: archivedCount,
                listBackground: bg,
              ),
            );
          },
        );
      },
    );

    final content = embedded
        ? inner
        : ListBackgroundScaffoldBody(settings: _settings, child: inner);

    if (embedded) return content;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: content,
    );
  }

  List<Widget> _settingsSections({
    required BuildContext context,
    required TextTheme textTheme,
    required Color accent,
    required int archivedCount,
    required ListBackgroundOption listBackground,
  }) {
    return [
      SettingsSectionLabel(
        label: 'Cuenta y sincronización',
        textTheme: textTheme,
        accent: accent,
      ),
      SettingsCard(
        children: [
          if (AuthService.instance.isAuthenticated) ...[
            SettingsRow(
              icon: Icons.account_circle_outlined,
              title: AuthService.instance.userEmail ?? 'Cuenta WODO',
              subtitle: AuthFlow.accountStatusLabel(
                isConfigured: AuthService.instance.isConfigured,
                isAuthenticated: true,
                syncEnabled: DeviceIdentity.instance.syncEnabled,
                syncState: SyncService.instance.state,
              ),
              trailing: 'Ver cuenta',
              accent: accent,
              onTap: () => AuthFlow.openAccount(context),
            ),
            const SettingsDivider(),
            SettingsRow(
              icon: Icons.devices_outlined,
              title: 'Este dispositivo',
              trailing: DeviceIdentity.instance.platformLabel,
              accent: accent,
              showChevron: false,
            ),
            const SettingsDivider(),
            SettingsRow(
              icon: Icons.cloud_sync_outlined,
              title: 'Sincronizar aquí',
              trailing: DeviceIdentity.instance.syncEnabled ? 'Activa' : 'Pausada',
              accent: accent,
              onTap: () => _toggleDeviceSync(context),
            ),
            const SettingsDivider(),
            SettingsRow(
              icon: Icons.sync_outlined,
              title: 'Sincronizar ahora',
              trailing: _syncLabel(),
              accent: accent,
              onTap: DeviceIdentity.instance.syncEnabled
                  ? () => _syncNow(context)
                  : null,
            ),
          ] else
            SettingsRow(
              icon: Icons.account_circle_outlined,
              title: 'Iniciar sesión',
              trailing: 'Local',
              accent: accent,
              onTap: () => _openAccount(context),
            ),
        ],
      ),
      const SizedBox(height: 20),
      SettingsSectionLabel(
        label: 'Apariencia',
        textTheme: textTheme,
        accent: accent,
      ),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.brightness_6_outlined,
            title: 'Tema',
            trailing: _settings.themeModeLabel,
            accent: accent,
            onTap: () => _pickTheme(context),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.wallpaper_outlined,
            title: 'Fondo de la lista',
            trailingWidget: _BackgroundSwatch(option: listBackground),
            accent: accent,
            onTap: () => _openFondo(context),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.calendar_view_month_outlined,
            title: 'Números en el heatmap',
            trailing: _settings.showHeatmapDayNumbersLabel,
            accent: accent,
            onTap: () => _pickHeatmapDayNumbers(context),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SettingsSectionLabel(
        label: 'Organización',
        textTheme: textTheme,
        accent: accent,
      ),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.inventory_2_outlined,
            title: 'Archivadas',
            trailing: archivedCount > 0 ? '$archivedCount' : null,
            accent: accent,
            onTap: () => _openArchived(context),
          ),
          if (onResetSelectedDay != null) ...[
            const SettingsDivider(),
            SettingsRow(
              icon: Icons.today_outlined,
              title: 'Ir a hoy',
              trailing: 'Restaurar fecha',
              accent: accent,
              onTap: () => _goToToday(context),
            ),
          ],
        ],
      ),
      const SizedBox(height: 20),
      SettingsSectionLabel(
        label: 'Datos',
        textTheme: textTheme,
        accent: accent,
      ),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.upload_outlined,
            title: 'Exportar datos',
            accent: accent,
            onTap: () => _export(context),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.download_outlined,
            title: 'Importar datos',
            accent: accent,
            onTap: () => _import(context),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.delete_forever_outlined,
            title: 'Borrar todos los datos',
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            onTap: () => _wipe(context),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SettingsSectionLabel(
        label: 'Acerca de',
        textTheme: textTheme,
        accent: accent,
      ),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.info_outline,
            title: 'Acerca de esta app',
            accent: accent,
            onTap: () => _openAbout(context),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.tag_outlined,
            title: 'Versión',
            trailing: Config.version,
            accent: accent,
            showChevron: false,
          ),
        ],
      ),
    ];
  }

  String _syncLabel() {
    if (!AuthService.instance.isConfigured) return 'Pendiente';
    if (!DeviceIdentity.instance.syncEnabled) return 'Pausada';
    return switch (SyncService.instance.state) {
      SyncState.unavailable => 'Inicia sesión',
      SyncState.idle => 'Actualizado',
      SyncState.syncing => 'Sincronizando',
      SyncState.error => 'Error',
    };
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({required this.option});

  final ListBackgroundOption option;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    Widget fill;
    switch (option.kind) {
      case ListBackgroundKind.solid:
        if (option.hasAsset) {
          fill = Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                option.assetPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: option.resolveSolid(brightness)),
              ),
              ColoredBox(
                color: option.resolveSolid(brightness).withValues(alpha: 0.55),
              ),
            ],
          );
        } else {
          fill = ColoredBox(color: option.resolveSolid(brightness));
        }
      case ListBackgroundKind.gradient:
        final colors =
            option.resolveGradient(brightness) ??
            [AppColors.neutral00, AppColors.neutral20];
        fill = DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
        );
      case ListBackgroundKind.brandRosa:
        fill = Image.asset(
          ListBackgrounds.rosaAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF2327D)),
        );
      case ListBackgroundKind.brandVerde:
        fill = const ColoredBox(color: AppColors.primary00);
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: option.resolveAccent(brightness)),
      ),
      clipBehavior: Clip.antiAlias,
      child: fill,
    );
  }
}
