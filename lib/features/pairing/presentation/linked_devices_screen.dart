import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/domain/auth_errors.dart';
import '../../settings/presentation/widgets/settings_section.dart';
import '../data/pairing_service.dart';
import 'approve_pairing_screen.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  var _loading = true;
  Object? _error;
  List<LinkedDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await PairingService.instance.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openApprove() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ApprovePairingScreen(),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _revoke(LinkedDevice device) async {
    if (device.isThisDevice) {
      await AppAlerts.show(
        context,
        message:
            'Para dejar de usar este dispositivo, cierra sesión desde Mi cuenta.',
        type: AppAlertType.warning,
      );
      return;
    }

    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Revocar dispositivo',
      message:
          '«${device.label}» dejará de aparecer como vinculado. '
          'Podrá volver a vincularse con un código nuevo.',
      confirmLabel: 'Revocar',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await PairingService.instance.revokeDevice(device.appUserId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispositivo revocado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: AuthErrors.message(error, registering: false),
        type: AppAlertType.error,
      );
    }
  }

  String _syncHint(LinkedDevice device) {
    final at = device.lastSyncedAt;
    if (at == null) return 'Sin sincronizar aún';
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Última sync ${local.day}/${local.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos vinculados'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AuthErrors.message(_error!, registering: false),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    SettingsSectionLabel(
                      label: 'Vincular',
                      textTheme: textTheme,
                      accent: accent,
                    ),
                    SettingsCard(
                      children: [
                        SettingsRow(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Vincular otro dispositivo',
                          subtitle:
                              'Introduce el código que muestra web u otro equipo',
                          accent: accent,
                          onTap: _openApprove,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SettingsSectionLabel(
                      label: 'Tus dispositivos',
                      textTheme: textTheme,
                      accent: accent,
                    ),
                    if (_devices.isEmpty)
                      SettingsCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Aún no hay dispositivos registrados. '
                              'Sincroniza en este equipo o vincula otro con un código.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppSurface.secondary(context),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SettingsCard(
                        children: [
                          for (var i = 0; i < _devices.length; i++) ...[
                            if (i > 0) const SettingsDivider(),
                            SettingsRow(
                              icon: _devices[i].isThisDevice
                                  ? Icons.smartphone_rounded
                                  : Icons.devices_other_outlined,
                              title: _devices[i].label,
                              subtitle: _syncHint(_devices[i]),
                              accent: accent,
                              trailing: _devices[i].isThisDevice
                                  ? 'Aquí'
                                  : 'Revocar',
                              onTap: _devices[i].isThisDevice
                                  ? null
                                  : () => _revoke(_devices[i]),
                              showChevron: !_devices[i].isThisDevice,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
    );
  }
}
