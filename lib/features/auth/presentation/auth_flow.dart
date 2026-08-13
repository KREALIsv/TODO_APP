import 'package:flutter/material.dart';

import '../../../global/widgets/app_alerts.dart';
import '../../settings/presentation/data_backup.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';
import '../domain/auth_errors.dart';
import '../domain/auth_session_expired_exception.dart';
import '../../encryption/data/vault_service.dart';
import '../../encryption/domain/cloud_vault_state.dart';
import '../../encryption/presentation/link_device_gate.dart';
import '../../encryption/presentation/recovery_code_screen.dart';
import '../../pairing/presentation/approve_pairing_screen.dart';
import '../../pairing/presentation/linked_devices_screen.dart';
import '../../pairing/presentation/qr_login_screen.dart';
import '../../settings/presentation/privacy_security_screen.dart';
import 'account_screen.dart';
import 'auth_screen.dart';

/// Shared navigation and feedback for sign-in / sign-out.
abstract final class AuthFlow {
  static Future<void> openLogin(
    BuildContext context, {
    String? contextTitle,
    String? contextMessage,
  }) async {
    AuthService.instance.consumeSessionEndedMessage();
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AuthScreen(
          contextTitle: contextTitle,
          contextMessage: contextMessage,
        ),
      ),
    );
    if (signedIn != true || !context.mounted) return;
    await VaultService.instance.refreshSecurity();
    if (!context.mounted) return;
    await _showSignedInSnack(context);
    if (!context.mounted) return;
    await _maybeOpenVaultGate(context);
  }

  static Future<void> openQrLogin(BuildContext context) async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const QrLoginScreen(),
      ),
    );
    if (signedIn != true || !context.mounted) return;
    await VaultService.instance.refreshSecurity();
    if (!context.mounted) return;
    await _showSignedInSnack(context);
    if (!context.mounted) return;
    await _maybeOpenVaultGate(context);
  }

  static Future<void> _maybeOpenVaultGate(BuildContext context) async {
    final state = VaultService.instance.state;
    if (state == CloudVaultState.authOnly ||
        state == CloudVaultState.revoked) {
      await openLinkDeviceGate(context);
    }
  }

  static Future<void> openApprovePairing(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ApprovePairingScreen(),
      ),
    );
  }

  static Future<void> openLinkedDevices(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const LinkedDevicesScreen(),
      ),
    );
  }

  static Future<void> _showSignedInSnack(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AuthService.instance.userEmail == null
              ? 'Sesión iniciada'
              : 'Sesión iniciada como ${AuthService.instance.userEmail}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (DeviceIdentity.instance.syncEnabled) {
      try {
        await syncNow(context);
      } on AuthSessionExpiredException {
        // Login just succeeded; ignore stale expiry side effects.
      }
    }
  }

  static Future<void> logout(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Cerrar sesión',
      message: 'Tus datos locales se conservarán en este dispositivo.',
      confirmLabel: 'Cerrar sesión',
      isDestructive: true,
    );
    if (!confirmed) return;

    await AuthService.instance.logout();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesión cerrada'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String accountStatusLabel({
    required bool isConfigured,
    required bool isAuthenticated,
    required bool syncEnabled,
    required SyncState syncState,
  }) {
    if (!isConfigured) {
      return 'Sincronización no configurada (solo builds de desarrollo)';
    }
    if (!isAuthenticated) return 'Modo local · solo en este dispositivo';
    final vault = VaultService.instance.state;
    if (vault == CloudVaultState.authOnly) {
      return 'Sesión iniciada · vincula este dispositivo para ver tus datos';
    }
    if (vault == CloudVaultState.revoked) {
      return 'Este dispositivo fue desvinculado';
    }
    if (!syncEnabled) return 'Sincronización pausada en este dispositivo';
    if (vault == CloudVaultState.vaultReady) {
      return switch (syncState) {
        SyncState.syncing => 'Datos protegidos · sincronizando…',
        SyncState.error => 'Datos protegidos · error al sincronizar',
        SyncState.idle => 'Datos protegidos · al día',
        SyncState.unavailable => 'Datos protegidos · listo para sincronizar',
        SyncState.accountSwitchRequired =>
          'Datos protegidos · elegí qué hacer con tus datos locales',
      };
    }
    return switch (syncState) {
      SyncState.syncing => 'Sincronizando…',
      SyncState.error => 'Error al sincronizar',
      SyncState.accountSwitchRequired => 'Elegí qué hacer con tus datos locales',
      SyncState.idle => 'Datos al día en la nube',
      SyncState.unavailable => isAuthenticated
          ? 'Listo para sincronizar'
          : 'Inicia sesión para sincronizar',
    };
  }

  static Future<void> openLinkDeviceGate(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const LinkDeviceGate(),
      ),
    );
  }

  static Future<void> openPrivacySecurity(BuildContext context) {
    return PrivacySecurityScreen.open(context);
  }

  static Future<void> enableCloudProtection(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Proteger mis datos en la nube',
      message:
          'Tus notas y tareas se encriptarán antes de subirlas. '
          'Otros dispositivos tendrán que vincularse (QR) o usar un código '
          'de recuperación. Deberás guardar ese código; sin él no hay '
          'recuperación si pierdes todos los dispositivos.',
      confirmLabel: 'Activar protección',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final code = await VaultService.instance.enableProtection();
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RecoveryCodeScreen(recoveryCode: code),
        ),
      );
      await SyncService.instance.resetAndSync();
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        title: 'Protección activada',
        message: 'Tus datos en la nube quedan encriptados de extremo a extremo.',
        type: AppAlertType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: AuthErrors.message(error, registering: false),
        type: AppAlertType.error,
      );
    }
  }

  static Future<void> regenerateRecoveryCode(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Regenerar código de recuperación',
      message:
          'Se creará un código nuevo. El anterior dejará de funcionar de '
          'inmediato.\n\n'
          'Guarda el nuevo código en un lugar seguro; sin él no podrás '
          'recuperar tus datos si pierdes todos los dispositivos.',
      confirmLabel: 'Regenerar código',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final code = await VaultService.instance.regenerateRecoveryCode();
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RecoveryCodeScreen(
            recoveryCode: code,
            isRegeneration: true,
          ),
        ),
      );
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        title: 'Código actualizado',
        message:
            'El código anterior ya no sirve. Usa el nuevo si necesitas '
            'recuperar tus datos sin otro dispositivo.',
        type: AppAlertType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: AuthErrors.message(error, registering: false),
        type: AppAlertType.error,
      );
    }
  }

  static Future<void> openAccount(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AccountScreen(),
      ),
    );
  }

  static Future<void> syncNow(BuildContext context) async {
    try {
      await SyncService.instance.syncNow();
    } on AuthSessionExpiredException catch (error) {
      // Avoid a second dialog from [SessionExpiryListener] on top of login.
      AuthService.instance.consumeSessionEndedMessage();
      if (!context.mounted) return;
      await AppAlerts.showWithAction(
        context,
        title: AuthErrors.sessionExpiredTitle,
        message: error.userMessage,
        type: AppAlertType.warning,
        actionLabel: 'Iniciar sesión',
        dismissLabel: 'Ahora no',
        onAction: () {
          openLogin(
            context,
            contextTitle: 'Volver a sincronizar',
            contextMessage:
                'Inicia sesión con la misma cuenta que usas en la web '
                'para traer tus notas y tareas.',
          );
        },
      );
      return;
    }

    if (!context.mounted) return;

    final error = SyncService.instance.errorMessage;
    if (SyncService.instance.requiresAccountSwitch) {
      await AppAlerts.show(
        context,
        message: 'Primero elegí qué hacer con los datos locales de otra cuenta.',
        type: AppAlertType.warning,
      );
      return;
    }

    await AppAlerts.show(
      context,
      message: error == null
          ? 'Tus datos están actualizados.'
          : AuthErrors.message(StateError(error), registering: false),
      type: error == null ? AppAlertType.success : AppAlertType.error,
    );
  }

  static Future<void> deleteCloudAccount(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar cuenta en la nube',
      message:
          'Se borrará tu cuenta WODO en el servidor y dejarás de sincronizar '
          'con otros dispositivos.\n\n'
          'Tus notas y tareas en ESTE dispositivo se conservarán.',
      confirmLabel: 'Eliminar en la nube',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      if (AuthService.instance.isConfigured) {
        await AuthService.instance.deleteRemoteAccount();
      }
      await DeviceIdentity.instance.setSyncEnabled(false);
      await AuthService.instance.logout();
      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta eliminada en la nube. Tus datos locales se conservaron.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        type: AppAlertType.error,
      );
    }
  }

  static Future<void> deleteAccountAndLocalData(BuildContext context) async {
    final first = await AppAlerts.confirm(
      context,
      title: 'Eliminar cuenta y datos locales',
      message:
          'Se borrará tu cuenta en la nube y TODAS las notas, tareas y '
          'archivos de este dispositivo. Esta acción no se puede deshacer.',
      confirmLabel: 'Continuar',
      isDestructive: true,
    );
    if (!first || !context.mounted) return;

    final second = await AppAlerts.confirm(
      context,
      title: '¿Seguro?',
      message:
          'Confirma que quieres eliminar tu cuenta y borrar todo el contenido '
          'local permanentemente.',
      confirmLabel: 'Borrar todo',
      isDestructive: true,
    );
    if (!second || !context.mounted) return;

    try {
      if (AuthService.instance.isConfigured &&
          AuthService.instance.isAuthenticated) {
        await AuthService.instance.deleteRemoteAccount();
      }
      await resetAllAppContent();
      await DeviceIdentity.instance.setSyncEnabled(false);
      await AuthService.instance.logout();
      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      await AppAlerts.show(
        context,
        message: 'Cuenta eliminada y datos locales borrados',
        type: AppAlertType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      await AppAlerts.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        type: AppAlertType.error,
      );
    }
  }
}
