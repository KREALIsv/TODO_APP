import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/domain/auth_errors.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../data/pairing_service.dart';

/// Trusted device: enter code / paste QR payload to approve a new device.
class ApprovePairingScreen extends StatefulWidget {
  const ApprovePairingScreen({super.key});

  @override
  State<ApprovePairingScreen> createState() => _ApprovePairingScreenState();
}

class _ApprovePairingScreenState extends State<ApprovePairingScreen> {
  final _controller = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    setState(() {});
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      await AppAlerts.show(
        context,
        message: 'Introduce el código que muestra el otro dispositivo.',
        type: AppAlertType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await PairingService.instance.approveFromScanOrCode(raw);
      if (!mounted) return;
      await AppAlerts.show(
        context,
        title: 'Dispositivo vinculado',
        message:
            'El otro dispositivo ya puede sincronizar con tu cuenta.',
        type: AppAlertType.success,
      );
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
        title: const Text('Vincular dispositivo'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: 'Vincular dispositivo',
        subtitle:
            'En el otro equipo elige «Entrar con tu teléfono» y escribe aquí '
            'el código de 8 caracteres (o pega el contenido del QR).',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_submitting) _submit();
              },
              decoration: InputDecoration(
                labelText: 'Código de vinculación',
                hintText: 'Ej. AB12CD34',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Pegar',
                  onPressed: _submitting ? null : _paste,
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Al confirmar, ese dispositivo iniciará sesión con tu cuenta '
              'y podrá sincronizar notas y tareas.',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Confirmar vinculación',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
