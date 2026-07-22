import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../settings/presentation/widgets/settings_section.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';
import '../data/auth_session_repository.dart';
import '../domain/auth_errors.dart';
import 'forgot_password_screen.dart';

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

  bool get _canUseAnotherAccount =>
      !_registering && _email.text.trim().isNotEmpty;

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
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_registering ? 'Crear cuenta' : 'Iniciar sesión'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          SettingsSectionLabel(
            label: widget.contextTitle ?? 'Sincronización multidispositivo',
            textTheme: textTheme,
            accent: accent,
          ),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.contextMessage ??
                      'Tus notas siguen disponibles sin conexión. Al iniciar sesión se combinarán de forma segura con tu cuenta.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
                ),
              ),
            ],
          ),
          if (_showRememberedEmailHint && !_registering) ...[
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Última cuenta usada en este dispositivo',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppSurface.secondary(context),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _submitting ? null : _useAnotherAccount,
                      child: const Text('Usar otra cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'tu@correo.com',
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty || !trimmed.contains('@')) {
                        return 'Ingresa un correo válido.';
                      }
                      return null;
                    },
                  ),
                ),
                const SettingsDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_submitting) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
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
                ),
              ],
            ),
          ),
          if (!_registering) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting ? null : _openForgotPassword,
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _registering ? 'Crear cuenta y sincronizar' : 'Iniciar sesión',
            ),
          ),
          if (_canUseAnotherAccount && !_showRememberedEmailHint)
            TextButton(
              onPressed: _submitting ? null : _useAnotherAccount,
              child: const Text('Usar otra cuenta'),
            ),
          TextButton(
            onPressed: _submitting
                ? null
                : () => setState(() {
                      _registering = !_registering;
                      _obscurePassword = true;
                    }),
            child: Text(
              _registering ? 'Ya tengo una cuenta' : 'Crear una cuenta nueva',
            ),
          ),
        ],
      ),
    );
  }
}
