import 'package:flutter/material.dart';

import '../../../global/widgets/app_alerts.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';
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
}
