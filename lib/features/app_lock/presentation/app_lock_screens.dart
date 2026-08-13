import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../features/encryption/data/crypto_service.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../../settings/domain/privacy_security_status.dart';
import '../app_lock_controller.dart';

/// Shared PIN field: 4–8 digits, numeric keyboard.
class AppLockPinField extends StatelessWidget {
  const AppLockPinField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 8,
      enableSuggestions: false,
      autocorrect: false,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        helperText: '4 a 8 dígitos',
      ),
    );
  }
}

/// Create a new PIN (enter + confirm). Pops the PIN string on success.
class AppLockSetupScreen extends StatefulWidget {
  const AppLockSetupScreen({
    super.key,
    this.title = 'Bloquear esta app',
    this.subtitle = PrivacySecurityCopy.appLockSetupSubtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text;
    final confirm = _confirm.text;
    if (!CryptoService.isValidPin(pin)) {
      await AppAlerts.show(
        context,
        message: 'El PIN debe tener entre 4 y 8 dígitos.',
        type: AppAlertType.warning,
      );
      return;
    }
    if (pin != confirm) {
      await AppAlerts.show(
        context,
        message: 'Los PIN no coinciden.',
        type: AppAlertType.warning,
      );
      return;
    }
    setState(() => _busy = true);
    if (!mounted) return;
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nuevo PIN'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: widget.title,
        subtitle: widget.subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppLockPinField(
              controller: _pin,
              label: 'PIN',
              enabled: !_busy,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            AppLockPinField(
              controller: _confirm,
              label: 'Repite el PIN',
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Guardar PIN',
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompt for the current PIN. Pops the PIN string (not verified yet).
class AppLockPinPromptScreen extends StatefulWidget {
  const AppLockPinPromptScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<AppLockPinPromptScreen> createState() => _AppLockPinPromptScreenState();
}

class _AppLockPinPromptScreenState extends State<AppLockPinPromptScreen> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text;
    if (!CryptoService.isValidPin(pin)) {
      await AppAlerts.show(
        context,
        message: 'El PIN debe tener entre 4 y 8 dígitos.',
        type: AppAlertType.warning,
      );
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: widget.title,
        subtitle: widget.subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppLockPinField(
              controller: _pin,
              label: 'PIN',
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(label: 'Continuar', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// Full-screen unlock used at cold start and as an in-session overlay.
class AppLockUnlockScreen extends StatefulWidget {
  const AppLockUnlockScreen({super.key, this.blocking = true});

  final bool blocking;

  @override
  State<AppLockUnlockScreen> createState() => _AppLockUnlockScreenState();
}

class _AppLockUnlockScreenState extends State<AppLockUnlockScreen> {
  final _pin = TextEditingController();
  var _busy = false;
  var _error = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text;
    if (!CryptoService.isValidPin(pin)) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    final ok = await AppLockFlow.unlock(pin);
    if (!mounted) return;
    if (ok) {
      setState(() => _busy = false);
      return;
    }
    _pin.clear();
    setState(() {
      _busy = false;
      _error = true;
    });
  }

  Future<void> _forgotPin() async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: '¿Olvidaste el PIN?',
      message: PrivacySecurityCopy.appLockForgotMessage,
      confirmLabel: 'Borrar notas locales',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppLockFlow.resetForgottenPin();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !widget.blocking,
      child: Scaffold(
        body: AuthPageShell(
          title: 'WODO está bloqueada',
          subtitle: PrivacySecurityCopy.appLockUnlockSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppLockPinField(
                controller: _pin,
                label: 'PIN',
                enabled: !_busy,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error) ...[
                const SizedBox(height: 8),
                Text(
                  'PIN incorrecto',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: 'Desbloquear',
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
              AuthTextLink(
                label: 'Olvidé el PIN',
                onPressed: _busy ? null : _forgotPin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation helpers for enabling / disabling / changing the app lock.
abstract final class AppLockFlow {
  static Future<bool> enable(BuildContext context) async {
    if (!LocalStorageService.instance.isSessionUnlocked) {
      if (context.mounted) {
        await AppAlerts.show(
          context,
          message: 'No se pudo activar el bloqueo en este dispositivo.',
          type: AppAlertType.error,
        );
      }
      return false;
    }
    final pin = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const AppLockSetupScreen()),
    );
    if (pin == null || !context.mounted) return false;
    try {
      await LocalStorageService.instance.enableAppLock(pin);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WODO pedirá este PIN al abrir la app'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        await AppAlerts.show(
          context,
          message: '$error',
          type: AppAlertType.error,
        );
      }
      return false;
    }
  }

  static Future<bool> disable(BuildContext context) async {
    final pin = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const AppLockPinPromptScreen(
          title: 'Desactivar bloqueo',
          subtitle: 'Introduce tu PIN para dejar de bloquear esta app.',
        ),
      ),
    );
    if (pin == null || !context.mounted) return false;
    final ok = await LocalStorageService.instance.disableAppLock(pin);
    if (!context.mounted) return ok;
    if (!ok) {
      await AppAlerts.show(
        context,
        message: 'PIN incorrecto.',
        type: AppAlertType.error,
      );
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bloqueo desactivado en este dispositivo'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  }

  static Future<bool> changePin(BuildContext context) async {
    final current = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const AppLockPinPromptScreen(
          title: 'PIN actual',
          subtitle: 'Introduce el PIN vigente para cambiarlo.',
        ),
      ),
    );
    if (current == null || !context.mounted) return false;
    final verified = await LocalStorageService.instance.verifyPin(current);
    if (!verified) {
      if (context.mounted) {
        await AppAlerts.show(
          context,
          message: 'PIN incorrecto.',
          type: AppAlertType.error,
        );
      }
      return false;
    }
    if (!context.mounted) return false;
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const AppLockSetupScreen(
          title: 'Nuevo PIN',
          subtitle: 'Elige un PIN de 4 a 8 dígitos para este dispositivo.',
        ),
      ),
    );
    if (next == null || !context.mounted) return false;
    final ok = await LocalStorageService.instance.changePin(
      currentPin: current,
      newPin: next,
    );
    if (!context.mounted) return ok;
    if (!ok) {
      await AppAlerts.show(
        context,
        message: 'No se pudo cambiar el PIN.',
        type: AppAlertType.error,
      );
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN actualizado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  }

  static Future<bool> unlock(String pin) {
    return AppLockController.instance.unlock(pin);
  }

  static Future<void> resetForgottenPin() {
    return AppLockController.instance.resetForgottenPin();
  }
}
