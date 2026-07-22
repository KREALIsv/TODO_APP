import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../settings/presentation/widgets/settings_section.dart';

/// Phase 1: guidance until password reset email (SMTP) ships in phase 2.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar acceso'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          SettingsSectionLabel(
            label: 'Próximamente',
            textTheme: textTheme,
            accent: accent,
          ),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Estamos preparando la recuperación de contraseña por correo. '
                  'Mientras tanto, prueba lo siguiente:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppSurface.secondary(context),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(
            label: 'Qué puedes hacer ahora',
            textTheme: textTheme,
            accent: accent,
          ),
          SettingsCard(
            children: [
              _TipRow(
                icon: Icons.visibility_outlined,
                text:
                    'Usa el ojo en el campo contraseña para comprobar que la escribiste bien.',
              ),
              const SettingsDivider(),
              _TipRow(
                icon: Icons.alternate_email_outlined,
                text:
                    'Revisa el correo: debe ser exactamente el de registro (minúsculas, sin espacios).',
              ),
              const SettingsDivider(),
              _TipRow(
                icon: Icons.swap_horiz_outlined,
                text:
                    'Si entraste con otro correo antes, pulsa «Usar otra cuenta» en el login.',
              ),
              const SettingsDivider(),
              _TipRow(
                icon: Icons.person_add_alt_1_outlined,
                text:
                    'Si olvidaste la contraseña y no hay recuperación aún, puedes crear '
                    'la cuenta otra vez con el mismo correo después de que un administrador '
                    'elimine el usuario bloqueado en el servidor.',
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver al inicio de sesión'),
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: AppSurface.title(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
