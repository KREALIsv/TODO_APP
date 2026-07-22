import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../settings/presentation/widgets/settings_section.dart';
import '../../sync/data/sync_service.dart';
import '../data/auth_service.dart';

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

  AuthService get _auth => AuthService.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      if (_registering) {
        await _auth.register(email: _email.text, password: _password.text);
      } else {
        await _auth.login(email: _email.text, password: _password.text);
      }
      await SyncService.instance.syncNow();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
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
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Contraseña'),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _registering ? 'Crear cuenta y sincronizar' : 'Iniciar sesión',
            ),
          ),
          TextButton(
            onPressed: _submitting
                ? null
                : () => setState(() => _registering = !_registering),
            child: Text(
              _registering ? 'Ya tengo una cuenta' : 'Crear una cuenta nueva',
            ),
          ),
        ],
      ),
    );
  }
}
