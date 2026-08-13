import 'package:flutter/material.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../global/themes/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../encryption/data/vault_service.dart';
import '../../encryption/domain/cloud_vault_state.dart';

/// The four product states for privacy / cloud protection.
enum PrivacySecurityPhase {
  /// Layer 1: no account, local-only.
  local,

  /// Layer 2: signed in, cloud sync without E2EE.
  syncUnprotected,

  /// Layer 3 pending: account has E2EE, this device has no DEK.
  pendingLink,

  /// Layer 3 ready: this device can read protected cloud data.
  protected,
}

/// Copy and status for Cuenta / Privacidad. Single source of truth.
abstract final class AccountSyncCopy {
  static const sectionCaption = 'Tener tus datos en varios dispositivos';
  static const loginTitle = 'Iniciar sesión';
  static const loginSubtitle = 'Tener tus datos en varios dispositivos';
  static const loginContextTitle = 'Sincronización multidispositivo';
  static const loginContextMessage =
      'Tus notas siguen disponibles sin conexión. Al iniciar sesión se '
      'combinarán con tu cuenta para tenerlas en varios dispositivos.';
}

abstract final class PrivacySecurityCopy {
  static const sectionCaption =
      'Que ni WODO pueda leer el contenido en la nube';
  static const protectCta = 'Proteger mis datos';
  static const protectSubtitle =
      'Cifrado de extremo a extremo, opcional. El servidor no podrá leer '
      'tus notas.';
  static const exportSubtitle = 'Copia de seguridad de este dispositivo';
  static const importSubtitle = 'Reemplaza las notas de este dispositivo';
  static const appLockTitle = 'Bloquear esta app';
  static const appLockOffSubtitle =
      'Pide un PIN al abrir WODO en este dispositivo';
  static const appLockOnSubtitle = 'PIN activo en este dispositivo';
  static const appLockSetupSubtitle =
      'El PIN envuelve la clave de este dispositivo. No es la clave de la nube '
      'ni se sincroniza. Si lo olvidas, las notas locales de este equipo no '
      'se podrán leer.';
  static const appLockUnlockSubtitle =
      'Introduce el PIN de este dispositivo para ver tus notas.';
  static const appLockForgotMessage =
      'Si olvidas el PIN, las notas de este dispositivo no se podrán leer. '
      'Puedes borrarlas y empezar de cero aquí. Si tienes cuenta o un backup, '
      'podrás recuperarlas después.';
  static const appLockChangePinTitle = 'Cambiar PIN';
  static const appLockChangePinSubtitle =
      'El PIN envuelve la clave de este dispositivo';
}

class PrivacySecurityStatus {
  const PrivacySecurityStatus({
    required this.phase,
    required this.title,
    required this.body,
    required this.hubSubtitle,
    required this.hubTrailing,
    required this.icon,
    required this.tone,
  });

  final PrivacySecurityPhase phase;
  final String title;
  final String body;
  final String hubSubtitle;
  final String? hubTrailing;
  final IconData icon;
  final Color tone;

  static PrivacySecurityStatus resolve({
    bool? authenticated,
    VaultService? vault,
    Color accent = AppColors.primary,
  }) {
    final signedIn = authenticated ?? AuthService.instance.isAuthenticated;
    final cloud = vault ?? VaultService.instance;

    if (!signedIn) {
      final localOn = LocalStorageService.instance.isEnabled;
      return PrivacySecurityStatus(
        phase: PrivacySecurityPhase.local,
        title: 'Local',
        body: localOn
            ? 'Usas WODO en este dispositivo, sin cuenta. Tus notas se '
                  'guardan cifradas aquí. Exporta un backup si quieres una '
                  'copia de seguridad.'
            : 'Usas WODO en este dispositivo, sin cuenta. Exporta un backup '
                  'si quieres una copia de seguridad.',
        hubSubtitle: PrivacySecurityCopy.sectionCaption,
        hubTrailing: 'Local',
        icon: Icons.shield_outlined,
        tone: AppColors.neutral60,
      );
    }

    if (!cloud.accountEncryptionEnabled) {
      return PrivacySecurityStatus(
        phase: PrivacySecurityPhase.syncUnprotected,
        title: 'Sync sin protección',
        body:
            'Tus datos se sincronizan entre dispositivos. WODO puede leer '
            'el contenido en la nube hasta que actives la protección.',
        hubSubtitle: PrivacySecurityCopy.sectionCaption,
        hubTrailing: 'Opcional',
        icon: Icons.lock_open_rounded,
        tone: accent,
      );
    }

    if (cloud.state == CloudVaultState.authOnly ||
        cloud.state == CloudVaultState.revoked) {
      final revoked = cloud.state == CloudVaultState.revoked;
      return PrivacySecurityStatus(
        phase: PrivacySecurityPhase.pendingLink,
        title: 'Pendiente de vincular',
        body: revoked
            ? 'Este dispositivo fue desvinculado. Vuelve a vincularlo con QR '
                  'o usa tu código de recuperación.'
            : 'Tu cuenta está protegida, pero este equipo aún no tiene la '
                  'clave. Vincúlalo con QR o usa el código de recuperación.',
        hubSubtitle: PrivacySecurityCopy.sectionCaption,
        hubTrailing: 'Pendiente',
        icon: Icons.link_rounded,
        tone: accent,
      );
    }

    return PrivacySecurityStatus(
      phase: PrivacySecurityPhase.protected,
      title: 'Protegido',
      body:
          'Tus notas se cifran en este dispositivo antes de subir a la '
          'nube. Ni WODO puede leerlas.',
      hubSubtitle: PrivacySecurityCopy.sectionCaption,
      hubTrailing: 'Activa',
      icon: Icons.verified_user_outlined,
      tone: AppColors.primary,
    );
  }
}

/// Backward-compatible helpers used by older call sites / tests.
String privacySecuritySettingsSummary({required bool authenticated}) {
  return PrivacySecurityStatus.resolve(
    authenticated: authenticated,
  ).hubSubtitle;
}

String? privacySecuritySettingsTrailing({required bool authenticated}) {
  return PrivacySecurityStatus.resolve(
    authenticated: authenticated,
  ).hubTrailing;
}
