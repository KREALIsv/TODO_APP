import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';

/// Mandatory acknowledgment of the recovery code after enabling protection.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key, required this.recoveryCode});

  final String recoveryCode;

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  var _confirmed = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.recoveryCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _finish() async {
    if (!_confirmed) {
      await AppAlerts.show(
        context,
        message: 'Confirma que guardaste el código antes de continuar.',
        type: AppAlertType.warning,
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Código de recuperación'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: AuthPageShell(
          title: 'Guarda tu código de recuperación',
          subtitle:
              'Si pierdes todos tus dispositivos y este código, no podremos '
              'recuperar tus notas en la nube.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppSurface.panelOverlay(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppSurface.border(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    widget.recoveryCode,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar código'),
              ),
              const SizedBox(height: 16),
              Text(
                'Guárdalo en un gestor de contraseñas o imprímelo. '
                'WODO no puede volver a mostrártelo completo más adelante.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppSurface.secondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (value) =>
                    setState(() => _confirmed = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Lo guardé en un lugar seguro',
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: 'Continuar',
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
