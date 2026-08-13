import 'package:flutter/material.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_surface.dart';
import '../../app_lock/presentation/app_lock_screens.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../encryption/data/vault_service.dart';
import '../domain/privacy_security_status.dart';
import 'widgets/list_background_layer.dart';
import 'widgets/privacy_security_status_card.dart';
import 'widgets/settings_section.dart';

export '../domain/privacy_security_status.dart'
    show privacySecuritySettingsSummary, privacySecuritySettingsTrailing;

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
            final status = PrivacySecurityStatus.resolve(accent: accent);
            final local = LocalStorageService.instance;
            final localOn = local.isEnabled;
            final lockOn = local.isAppLockEnabled;
            final canLock = local.isSessionUnlocked || lockOn;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                PrivacySecurityStatusCard(status: status),
                const SizedBox(height: 20),
                SettingsSectionLabel(
                  label: 'En este dispositivo',
                  caption: 'Cifrado local, independiente de la nube',
                  textTheme: textTheme,
                  accent: accent,
                ),
                SettingsCard(
                  children: [
                    SettingsRow(
                      icon: localOn
                          ? Icons.phonelink_lock_rounded
                          : Icons.sd_storage_outlined,
                      title: 'Almacenamiento local',
                      subtitle: localOn
                          ? 'Notas, tareas y adjuntos se cifran en este '
                                'dispositivo. Cerrar sesión no los borra.'
                          : 'No se pudo cifrar el almacenamiento de este '
                                'dispositivo. Tus datos siguen en modo local.',
                      trailing: localOn ? 'Cifrado' : 'Sin cifrar',
                      accent: accent,
                      showChevron: false,
                      onTap: null,
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      icon: lockOn
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      title: PrivacySecurityCopy.appLockTitle,
                      subtitle: !canLock
                          ? 'Necesitas el cifrado local para activarlo'
                          : lockOn
                          ? PrivacySecurityCopy.appLockOnSubtitle
                          : PrivacySecurityCopy.appLockOffSubtitle,
                      accent: accent,
                      showChevron: false,
                      onTap: null,
                      trailingWidget: Switch.adaptive(
                        value: lockOn,
                        onChanged: !canLock
                            ? null
                            : (value) {
                                if (value) {
                                  AppLockFlow.enable(context);
                                } else {
                                  AppLockFlow.disable(context);
                                }
                              },
                      ),
                    ),
                    if (lockOn) ...[
                      const SettingsDivider(),
                      SettingsRow(
                        icon: Icons.pin_outlined,
                        title: PrivacySecurityCopy.appLockChangePinTitle,
                        subtitle: PrivacySecurityCopy.appLockChangePinSubtitle,
                        accent: accent,
                        onTap: () => AppLockFlow.changePin(context),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (!authenticated) ...[
                  SettingsSectionLabel(
                    label: 'Cuenta y sincronización',
                    caption: AccountSyncCopy.sectionCaption,
                    textTheme: textTheme,
                    accent: accent,
                  ),
                  SettingsCard(
                    children: [
                      SettingsRow(
                        icon: Icons.login_rounded,
                        title: AccountSyncCopy.loginTitle,
                        subtitle: AccountSyncCopy.loginSubtitle,
                        accent: accent,
                        onTap: () => AuthFlow.openSyncLogin(context),
                      ),
                    ],
                  ),
                ] else ...[
                  SettingsSectionLabel(
                    label: 'Protección en la nube',
                    caption: PrivacySecurityCopy.sectionCaption,
                    textTheme: textTheme,
                    accent: accent,
                  ),
                  SettingsCard(
                    children: _protectionRows(context, accent, status),
                  ),
                  const SizedBox(height: 20),
                  SettingsSectionLabel(
                    label: 'Dispositivos',
                    textTheme: textTheme,
                    accent: accent,
                  ),
                  SettingsCard(
                    children: [
                      SettingsRow(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Vincular otro dispositivo',
                        subtitle:
                            'Aprueba un código o QR para entrar en otro equipo',
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

  List<Widget> _protectionRows(
    BuildContext context,
    Color accent,
    PrivacySecurityStatus status,
  ) {
    switch (status.phase) {
      case PrivacySecurityPhase.syncUnprotected:
        return [
          SettingsRow(
            icon: Icons.lock_outline_rounded,
            title: PrivacySecurityCopy.protectCta,
            subtitle: PrivacySecurityCopy.protectSubtitle,
            trailing: 'Desactivada',
            accent: accent,
            onTap: () => AuthFlow.enableCloudProtection(context),
          ),
        ];
      case PrivacySecurityPhase.pendingLink:
        return [
          SettingsRow(
            icon: Icons.link_rounded,
            title: 'Vincula este dispositivo',
            subtitle:
                'QR desde un equipo de confianza, o código de recuperación',
            trailing: 'Pendiente',
            accent: accent,
            onTap: () => AuthFlow.openLinkDeviceGate(context),
          ),
        ];
      case PrivacySecurityPhase.protected:
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
      case PrivacySecurityPhase.local:
        return const [];
    }
  }
}
