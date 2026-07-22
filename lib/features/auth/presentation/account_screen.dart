import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../settings/presentation/widgets/settings_section.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';
import '../domain/user_profile.dart';
import 'auth_flow.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  UserProfile? _profile;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (AuthService.instance.isConfigured) {
        final profile = await AuthService.instance.fetchProfile();
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _loading = false;
        });
        return;
      }

      final email = AuthService.instance.userEmail;
      if (email == null) {
        throw StateError('No hay sesión activa.');
      }
      if (!mounted) return;
      setState(() {
        _profile = UserProfile(
          id: 'local',
          email: email,
          createdAt: DateTime.now(),
        );
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

  String get _email =>
      _profile?.email ?? AuthService.instance.userEmail ?? '—';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          AuthService.instance,
          SyncService.instance,
          DeviceIdentity.instance,
        ]),
        builder: (context, _) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar tu cuenta',
                      style: textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_error',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppSurface.secondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final syncStatus = AuthFlow.accountStatusLabel(
            isConfigured: AuthService.instance.isConfigured,
            isAuthenticated: AuthService.instance.isAuthenticated,
            syncEnabled: DeviceIdentity.instance.syncEnabled,
            syncState: SyncService.instance.state,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SettingsSectionLabel(
                label: 'Datos de cuenta',
                textTheme: textTheme,
                accent: accent,
              ),
              SettingsCard(
                children: [
                  _InfoRow(
                    label: 'Correo',
                    value: _email,
                  ),
                  const SettingsDivider(),
                  _InfoRow(
                    label: 'Dispositivo',
                    value: DeviceIdentity.instance.platformLabel,
                  ),
                  const SettingsDivider(),
                  _InfoRow(
                    label: 'Sincronización',
                    value: syncStatus,
                  ),
                  if (_profile != null && _profile!.id != 'local') ...[
                    const SettingsDivider(),
                    _InfoRow(
                      label: 'Cuenta creada',
                      value: _formatDate(_profile!.createdAt),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SettingsSectionLabel(
                label: 'Sesión',
                textTheme: textTheme,
                accent: accent,
              ),
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: Icons.logout_outlined,
                    title: 'Cerrar sesión',
                    accent: accent,
                    onTap: () async {
                      await AuthFlow.logout(context);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsSectionLabel(
                label: 'Eliminar cuenta',
                textTheme: textTheme,
                accent: AppColors.error,
              ),
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Puedes borrar tu cuenta en la nube y conservar las notas '
                      'de este dispositivo, o hacer una limpieza completa.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppSurface.secondary(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.cloud_off_outlined,
                    title: 'Eliminar cuenta en la nube',
                    subtitle: 'Conserva tus datos en este dispositivo',
                    iconColor: AppColors.error,
                    titleColor: AppColors.error,
                    onTap: () => AuthFlow.deleteCloudAccount(context),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.delete_forever_outlined,
                    title: 'Eliminar cuenta y datos locales',
                    subtitle: 'Limpieza total en este dispositivo y en la nube',
                    iconColor: AppColors.error,
                    titleColor: AppColors.error,
                    onTap: () => AuthFlow.deleteAccountAndLocalData(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppSurface.title(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
