import 'package:flutter/material.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../encryption/data/vault_service.dart';
import '../../encryption/domain/cloud_vault_state.dart';
import 'widgets/list_background_layer.dart';
import 'widgets/settings_section.dart';

/// Privacy, encryption and device-trust settings (E2EE, pairing, linked devices).
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PrivacySecurityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Privacidad y seguridad'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListBackgroundScaffoldBody(
        settings: null,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            AuthService.instance,
            VaultService.instance,
            LocalStorageService.instance,
          ]),
          builder: (context, _) {
            final authenticated = AuthService.instance.isAuthenticated;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _PrivacyStatusCard(
                  textTheme: textTheme,
                  accent: accent,
                  authenticated: authenticated,
                ),
                const SizedBox(height: 20),
                SettingsSectionLabel(
                  label: 'Este dispositivo',
                  textTheme: textTheme,
                  accent: accent,
                ),
                SettingsCard(
                  children: [
                    SettingsRow(
                      icon: LocalStorageService.instance.isEnabled
                          ? Icons.phonelink_lock_rounded
                          : Icons.sd_storage_outlined,
                      title: 'Almacenamiento local',
                      subtitle: LocalStorageService.instance.isEnabled
                          ? 'Notas, tareas y adjuntos se cifran en este '
                              'dispositivo. Cerrar sesión no los borra.'
                          : 'No se pudo cifrar el almacenamiento de este '
                              'dispositivo. Tus datos siguen en modo local.',
                      trailing: LocalStorageService.instance.isEnabled
                          ? 'Cifrado'
                          : 'Sin cifrar',
                      accent: accent,
                      showChevron: false,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!authenticated) ...[
                  SettingsCard(
                    children: [
                      SettingsRow(
                        icon: Icons.login_rounded,
                        title: 'Iniciar sesión',
                        subtitle:
                            'Necesitas una cuenta para activar la protección '
                            'y vincular dispositivos.',
                        accent: accent,
                        onTap: () => AuthFlow.openLogin(context),
                      ),
                    ],
                  ),
                ] else ...[
                  SettingsSectionLabel(
                    label: 'Protección de datos',
                    textTheme: textTheme,
                    accent: accent,
                  ),
                  SettingsCard(
                    children: _protectionRows(context, accent),
                  ),
                  const SizedBox(height: 20),
                  SettingsSectionLabel(
                    label: 'Dispositivos de confianza',
                    textTheme: textTheme,
                    accent: accent,
                  ),
                  SettingsCard(
                    children: [
                      SettingsRow(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Vincular dispositivo',
                        subtitle:
                            'Aprueba un código o QR desde otro equipo',
                        accent: accent,
                        onTap: () => AuthFlow.openApprovePairing(context),
                      ),
                      const SettingsDivider(),
                      SettingsRow(
                        icon: Icons.devices_other_outlined,
                        title: 'Dispositivos vinculados',
                        subtitle: 'Revisa o revoca acceso',
                        accent: accent,
                        onTap: () => AuthFlow.openLinkedDevices(context),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _protectionRows(BuildContext context, Color accent) {
    final vault = VaultService.instance;

    if (!vault.accountEncryptionEnabled) {
      return [
        SettingsRow(
          icon: Icons.lock_outline_rounded,
          title: 'Proteger mis datos en la nube',
          subtitle: 'Encriptación de extremo a extremo (opcional)',
          trailing: 'Desactivada',
          accent: accent,
          onTap: () => AuthFlow.enableCloudProtection(context),
        ),
      ];
    }

    if (vault.state == CloudVaultState.authOnly ||
        vault.state == CloudVaultState.revoked) {
      return [
        SettingsRow(
          icon: Icons.link_rounded,
          title: 'Vincula este dispositivo',
          subtitle: 'Tu cuenta está protegida; falta autorizar este equipo',
          trailing: 'Pendiente',
          accent: accent,
          onTap: () => AuthFlow.openLinkDeviceGate(context),
        ),
      ];
    }

    return [
      SettingsRow(
        icon: Icons.verified_user_outlined,
        title: 'Protección en la nube',
        subtitle: 'Tus datos se cifran antes de subir al servidor',
        trailing: 'Activa',
        accent: accent,
        showChevron: false,
        onTap: null,
      ),
      const SettingsDivider(),
      SettingsRow(
        icon: Icons.key_rounded,
        title: 'Regenerar código de recuperación',
        subtitle: 'Genera uno nuevo; el anterior dejará de funcionar',
        accent: accent,
        onTap: () => AuthFlow.regenerateRecoveryCode(context),
      ),
    ];
  }
}

class _PrivacyStatusCard extends StatelessWidget {
  const _PrivacyStatusCard({
    required this.textTheme,
    required this.accent,
    required this.authenticated,
  });

  final TextTheme textTheme;
  final Color accent;
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    final (title, body, icon, tone) = _resolveStatus();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurface.title(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppSurface.secondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String, IconData, Color) _resolveStatus() {
    if (!authenticated) {
      return (
        'Modo local',
        LocalStorageService.instance.isEnabled
            ? 'Tus notas se guardan cifradas en este dispositivo. '
                'Inicia sesión si quieres sincronizar o proteger la nube '
                'con E2EE.'
            : 'Puedes usar WODO sin cuenta. Inicia sesión para sincronizar '
                'o activar protección E2EE en la nube.',
        Icons.shield_outlined,
        AppColors.neutral60,
      );
    }

    final vault = VaultService.instance;
    if (!vault.accountEncryptionEnabled) {
      return (
        'Sin protección E2EE',
        'Tus datos en la nube no están cifrados de extremo a extremo. '
            'Puedes activarlo cuando quieras.',
        Icons.lock_open_rounded,
        accent,
      );
    }

    return switch (vault.state) {
      CloudVaultState.authOnly || CloudVaultState.revoked => (
        'Protección pendiente en este dispositivo',
        'Tu cuenta usa E2EE, pero este equipo aún no tiene acceso. '
            'Vincúlalo con QR o código de recuperación.',
        Icons.link_rounded,
        accent,
      ),
      CloudVaultState.vaultReady => (
        'Datos protegidos',
        'Tus notas y tareas se cifran en este dispositivo antes de '
            'sincronizarse con la nube.',
        Icons.verified_user_outlined,
        AppColors.primary,
      ),
      _ => (
        'Protección activa',
        'La encriptación de extremo a extremo está habilitada en tu cuenta.',
        Icons.shield_rounded,
        AppColors.primary,
      ),
    };
  }
}

/// Short summary for the settings hub row.
String privacySecuritySettingsSummary({
  required bool authenticated,
}) {
  if (!authenticated) {
    return LocalStorageService.instance.isEnabled
        ? 'Cifrado en este dispositivo'
        : 'Inicia sesión para sincronizar';
  }

  final vault = VaultService.instance;
  if (!vault.accountEncryptionEnabled) {
    return 'Protección E2EE desactivada';
  }

  return switch (vault.state) {
    CloudVaultState.authOnly || CloudVaultState.revoked =>
      'Vincula este dispositivo',
    CloudVaultState.vaultReady => 'E2EE activa',
    _ => 'Protección activa',
  };
}

/// Trailing label for the settings hub row.
String? privacySecuritySettingsTrailing({
  required bool authenticated,
}) {
  if (!authenticated) return null;

  final vault = VaultService.instance;
  if (!vault.accountEncryptionEnabled) return 'Opcional';
  if (vault.state == CloudVaultState.authOnly ||
      vault.state == CloudVaultState.revoked) {
    return 'Pendiente';
  }
  return 'Activa';
}
