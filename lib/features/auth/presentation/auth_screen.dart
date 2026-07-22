import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';
import '../data/auth_session_repository.dart';
import '../domain/auth_errors.dart';
import 'forgot_password_screen.dart';
import 'widgets/auth_page_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.contextTitle, this.contextMessage});

  final String? contextTitle;
  final String? contextMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _passwordHasText = false;
  bool _showRememberedEmailHint = false;

  AuthService get _auth => AuthService.instance;
  AuthSessionRepository get _sessions => AuthSessionRepository.instance;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
    _email.addListener(_onEmailChanged);
    final remembered = _sessions.lastLoginEmail;
    if (remembered != null && remembered.isNotEmpty) {
      _email.text = remembered;
      _showRememberedEmailHint = true;
    }
  }

  void _onPasswordChanged() {
    final hasText = _password.text.isNotEmpty;
    if (hasText != _passwordHasText) {
      setState(() => _passwordHasText = hasText);
    }
  }

  void _onEmailChanged() {
    if (_showRememberedEmailHint &&
        _email.text.trim().toLowerCase() !=
            (_sessions.lastLoginEmail ?? '').trim().toLowerCase()) {
      setState(() => _showRememberedEmailHint = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    await _sessions.clearRememberedLoginEmail();
    _email.clear();
    _password.clear();
    setState(() {
      _showRememberedEmailHint = false;
      _obscurePassword = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      if (_registering) {
        await _auth.register(email: _email.text, password: _password.text);
        await SyncService.instance.syncNow();
        if (!mounted) return;
        await AppAlerts.show(
          context,
          title: 'Cuenta creada',
          message:
              'Guarda tu contraseña en un lugar seguro. Por ahora no hay '
              'recuperación por correo; si la olvidas, tendrás que volver a '
              'registrar la cuenta.',
          type: AppAlertType.success,
        );
      } else {
        await _auth.login(email: _email.text, password: _password.text);
        await SyncService.instance.syncNow();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: AuthErrors.message(error, registering: _registering),
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _toggleMode() {
    setState(() {
      _registering = !_registering;
      _obscurePassword = true;
    });
  }

  bool get _canUseAnotherAccount =>
      !_registering && _email.text.trim().isNotEmpty;

  String get _subtitle {
    if (widget.contextMessage != null) return widget.contextMessage!;
    return _registering
        ? 'Crea tu cuenta para sincronizar notas y tareas entre dispositivos. '
            'Tus datos locales se mantienen sin conexión.'
        : 'Entra con tu cuenta WODO para sincronizar entre dispositivos. '
            'Sin sesión, todo sigue guardándose aquí en local.';
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _email.removeListener(_onEmailChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _registering ? 'Crear cuenta' : 'Iniciar sesión';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: title,
        subtitle: _subtitle,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showRememberedEmailHint && !_registering) ...[
                AuthInfoBanner(
                  message: 'Última cuenta en este dispositivo',
                  actionLabel: 'Cambiar',
                  onAction: _submitting ? null : _useAnotherAccount,
                ),
                const SizedBox(height: 18),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'tu@correo.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty || !trimmed.contains('@')) {
                    return 'Ingresa un correo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_submitting) _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  hintText: 'Mínimo 8 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: _passwordHasText
                      ? IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Usa al menos 8 caracteres.';
                  }
                  return null;
                },
              ),
              if (!_registering) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _submitting ? null : _openForgotPassword,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
              ] else
                const SizedBox(height: 8),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: _registering
                    ? 'Crear cuenta y sincronizar'
                    : 'Iniciar sesión',
                loading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              if (_canUseAnotherAccount && !_showRememberedEmailHint)
                Center(
                  child: TextButton(
                    onPressed: _submitting ? null : _useAnotherAccount,
                    child: const Text('Usar otra cuenta'),
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: _submitting ? null : _toggleMode,
                  child: Text(
                    _registering
                        ? 'Ya tengo una cuenta'
                        : 'Crear una cuenta nueva',
                  ),
                ),
              ),
              if (_registering) ...[
                const SizedBox(height: 4),
                Text(
                  'Al crear la cuenta aceptas que WODO guarde tus datos '
                  'sincronizados de forma segura en la nube.',
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppSurface.secondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
