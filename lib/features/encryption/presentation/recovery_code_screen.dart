import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/io/share_bytes_file.dart';
import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/domain/auth_errors.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../data/encryption_api.dart';

/// Mandatory acknowledgment of the recovery code after enabling protection.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key, required this.recoveryCode});

  final String recoveryCode;

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  var _confirmed = false;
  var _sharing = false;
  var _emailing = false;

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

  Future<void> _downloadTxt() async {
    setState(() => _sharing = true);
    try {
      final body = [
        'WODO — código de recuperación',
        '',
        'Guarda este archivo en un lugar seguro (gestor de contraseñas o impreso).',
        'Si pierdes todos tus dispositivos y este código, no podremos recuperar',
        'tus notas y tareas protegidas en la nube.',
        '',
        widget.recoveryCode,
        '',
        'https://app.wodo.app',
      ].join('\n');
      await shareBytesAsFile(
        bytes: Uint8List.fromList(utf8.encode(body)),
        fileName: 'wodo-codigo-recuperacion.txt',
        mimeType: 'text/plain',
        subject: 'Código de recuperación WODO',
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo guardar el archivo. Prueba a copiar el código.',
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _emailCopy() async {
    setState(() => _emailing = true);
    try {
      final result = await EncryptionApi.instance.emailRecoveryCode(
        widget.recoveryCode,
      );
      if (!mounted) return;
      if (result.skipped) {
        await AppAlerts.show(
          context,
          message:
              'El correo no está configurado en el servidor. '
              'Copia o descarga el código por ahora.',
          type: AppAlertType.warning,
        );
        return;
      }
      await AppAlerts.show(
        context,
        title: 'Correo enviado',
        message:
            'Revisa la bandeja de tu cuenta WODO (y spam). '
            'Quien acceda a ese correo podría usar el código.',
        type: AppAlertType.success,
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: AuthErrors.message(error, registering: false),
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _emailing = false);
    }
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
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _sharing ? null : _downloadTxt,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _sharing ? 'Preparando archivo…' : 'Descargar .txt',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _emailing ? null : _emailCopy,
                icon: _emailing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mail_outline_rounded),
                label: Text(
                  _emailing
                      ? 'Enviando…'
                      : 'Enviar también a mi correo',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Guárdalo en un gestor de contraseñas o imprímelo. '
                'WODO no puede volver a mostrártelo completo más adelante. '
                'El envío por correo es opcional: quien lea tu bandeja podría usar el código.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppSurface.secondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
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
