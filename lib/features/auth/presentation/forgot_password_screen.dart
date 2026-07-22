import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import 'widgets/auth_page_shell.dart';

/// Phase 1: guidance until password reset email (SMTP) ships in phase 2.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Recuperar acceso'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: 'Recuperar acceso',
        subtitle:
            'La recuperación por correo llegará pronto. Mientras tanto, '
            'prueba estas opciones:',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TipRow(
              icon: Icons.visibility_outlined,
              text:
                  'Usa el ojo en contraseña para comprobar que la escribiste bien.',
            ),
            const SizedBox(height: 14),
            _TipRow(
              icon: Icons.alternate_email_outlined,
              text:
                  'Revisa el correo: debe ser exactamente el de registro.',
            ),
            const SizedBox(height: 14),
            _TipRow(
              icon: Icons.swap_horiz_outlined,
              text: 'En el login, pulsa «Usar otra cuenta» si el email no es el correcto.',
            ),
            const SizedBox(height: 14),
            _TipRow(
              icon: Icons.person_add_alt_1_outlined,
              text:
                  'Si olvidaste la contraseña, un administrador puede eliminar '
                  'tu usuario en el servidor para que vuelvas a registrarte.',
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Volver al inicio de sesión',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: AppSurface.title(context),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
