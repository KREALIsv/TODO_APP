import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/domain/auth_errors.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../data/pairing_service.dart';
import 'scan_pairing_screen.dart';

/// Trusted device: scan QR with the camera, or enter / paste the code.
class ApprovePairingScreen extends StatefulWidget {
  const ApprovePairingScreen({super.key});

  @override
  State<ApprovePairingScreen> createState() => _ApprovePairingScreenState();
}

class _ApprovePairingScreenState extends State<ApprovePairingScreen> {
  final _controller = TextEditingController();
  var _submitting = false;
  var _showManual = false;

  bool get _scannerAvailable => pairingCameraScannerSupported();

  @override
  void initState() {
    super.initState();
    // On platforms without a camera scanner (web), start in manual mode.
    _showManual = !_scannerAvailable;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ScanPairingScreen(),
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
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
        message: 'El otro dispositivo ya puede sincronizar con tu cuenta.',
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
        subtitle: _scannerAvailable
            ? 'Escanea el QR que muestra el otro dispositivo (web u otro equipo), '
                'o introduce el código de 8 caracteres a mano.'
            : 'En el otro equipo elige «Entrar con tu teléfono» y escribe aquí '
                'el código de 8 caracteres (o pega el contenido del QR).',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_scannerAvailable) ...[
              AuthPrimaryButton(
                label: 'Escanear código QR',
                onPressed: _submitting ? null : _openScanner,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _showManual = !_showManual),
                icon: Icon(
                  _showManual
                      ? Icons.keyboard_hide_outlined
                      : Icons.keyboard_alt_outlined,
                ),
                label: Text(
                  _showManual
                      ? 'Ocultar entrada manual'
                      : 'Introducir código a mano',
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_showManual) ...[
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
            ] else if (!_scannerAvailable)
              const SizedBox.shrink()
            else
              Text(
                kIsWeb
                    ? 'En la web puedes pegar el código del QR.'
                    : 'La cámara es la forma más rápida. Si el QR no se lee, '
                        'usa el código de 8 caracteres.',
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
