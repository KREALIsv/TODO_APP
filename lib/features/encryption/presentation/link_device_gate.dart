import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../../pairing/presentation/qr_login_screen.dart';
import '../data/vault_service.dart';
import '../domain/cloud_vault_state.dart';
import 'unlock_recovery_screen.dart';

/// Full-screen gate when the account has E2EE but this device has no DEK.
class LinkDeviceGate extends StatelessWidget {
  const LinkDeviceGate({super.key});

  Future<void> _openQr(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const QrLoginScreen()),
    );
    await VaultService.instance.refreshSecurity();
  }

  Future<void> _openRecovery(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const UnlockRecoveryScreen()),
    );
    await VaultService.instance.refreshSecurity();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final revoked =
        VaultService.instance.state == CloudVaultState.revoked;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(revoked ? 'Dispositivo desvinculado' : 'Vincula este dispositivo'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: revoked ? 'Dispositivo desvinculado' : 'Vincula este dispositivo',
        subtitle: revoked
            ? 'Este dispositivo fue revocado. Vuelve a vincularlo con tu teléfono '
                'o usa tu código de recuperación.'
            : 'Tu sesión está activa. Para ver tus notas y tareas protegidas, '
                'vincula este dispositivo o usa tu código de recuperación.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(
              label: 'Mostrar código QR',
              onPressed: () => _openQr(context),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openRecovery(context),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Usar código de recuperación'),
            ),
            const SizedBox(height: 16),
            Text(
              'Las notas solo de este dispositivo (si las hay) siguen en local; '
              'la nube protegida espera la clave.',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
