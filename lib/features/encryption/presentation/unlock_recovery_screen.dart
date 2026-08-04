import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/domain/auth_errors.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../../sync/data/sync_service.dart';
import '../data/vault_service.dart';

class UnlockRecoveryScreen extends StatefulWidget {
  const UnlockRecoveryScreen({super.key});

  @override
  State<UnlockRecoveryScreen> createState() => _UnlockRecoveryScreenState();
}

class _UnlockRecoveryScreenState extends State<UnlockRecoveryScreen> {
  final _controller = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length < 16) {
      await AppAlerts.show(
        context,
        message: 'Introduce el código de recuperación completo.',
        type: AppAlertType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await VaultService.instance.unlockWithRecoveryCode(code);
      await SyncService.instance.syncNow();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: AuthErrors.message(error, registering: false),
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Código de recuperación'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: 'Recuperar datos protegidos',
        subtitle:
            'Tu sesión está activa, pero este dispositivo no tiene la clave. '
            'Introduce el código que guardaste al activar la protección.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Código de recuperación',
                hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              onSubmitted: (_) {
                if (!_submitting) _submit();
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Si no tienes el código ni otro dispositivo vinculado, '
              'los datos en la nube no se pueden recuperar.',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Desbloquear',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
