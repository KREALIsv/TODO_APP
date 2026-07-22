import 'package:flutter/material.dart';

import '../../../global/widgets/app_alerts.dart';
import '../../settings/presentation/data_backup.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';
import 'account_screen.dart';
import 'auth_screen.dart';

/// Shared navigation and feedback for sign-in / sign-out.
abstract final class AuthFlow {
  static Future<void> openLogin(
    BuildContext context, {
    String? contextTitle,
    String? contextMessage,
  }) async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AuthScreen(
          contextTitle: contextTitle,
          contextMessage: contextMessage,
        ),
      ),
    );
    if (signedIn != true || !context.mounted) return;

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
    if (!isConfigured) return 'Sincronización no disponible en esta versión';
    if (!isAuthenticated) return 'Modo local · solo en este dispositivo';
    if (!syncEnabled) return 'Sincronización pausada en este dispositivo';
    return switch (syncState) {
      SyncState.syncing => 'Sincronizando…',
      SyncState.error => 'Error al sincronizar',
      SyncState.idle => 'Datos al día en la nube',
      SyncState.unavailable => 'Inicia sesión para sincronizar',
    };
  }

  static Future<void> openAccount(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AccountScreen(),
      ),
    );
  }

  static Future<void> syncNow(BuildContext context) async {
    await SyncService.instance.syncNow();
    if (!context.mounted) return;

    final error = SyncService.instance.errorMessage;
    await AppAlerts.show(
      context,
      message: error ?? 'Tus datos están actualizados.',
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
