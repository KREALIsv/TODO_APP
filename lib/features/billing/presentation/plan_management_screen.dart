import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../settings/presentation/widgets/settings_section.dart';
import '../data/subscription_service.dart';
import 'plus_onboarding_screen.dart';

class PlanManagementScreen extends StatelessWidget {
  const PlanManagementScreen({super.key});

  Future<void> _openPlus(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlusOnboardingScreen()),
    );
  }

  Future<void> _openAccount(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionService.instance;
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi plan'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([service, AuthService.instance]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppSurface.cardDecoration(
                context,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      service.hasPlus
                          ? Icons.workspace_premium
                          : Icons.cloud_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WODO ${service.planLabel}',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.hasPlus
                              ? 'Tu sincronización está activa.'
                              : 'Tus datos viven en este dispositivo.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppSurface.secondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsSectionLabel(
              label: 'Incluido ahora',
              textTheme: textTheme,
              accent: accent,
            ),
            SettingsCard(
              children: const [
                SettingsRow(
                  icon: Icons.edit_note_outlined,
                  title: 'Notas y tareas locales ilimitadas',
                  showChevron: false,
                ),
                SettingsDivider(),
                SettingsRow(
                  icon: Icons.file_download_outlined,
                  title: 'Exportación y respaldo manual',
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!service.hasPlus) ...[
              FilledButton.icon(
                onPressed: () => _openPlus(context),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Conocer WODO Plus'),
              ),
              const SizedBox(height: 8),
              Text(
                'Plus agrega sincronización, respaldo automático y recuperación.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              ),
            ] else
              OutlinedButton(
                onPressed: service.manageUrl == null ? null : () {},
                child: const Text('Administrar suscripción'),
              ),
            if (!AuthService.instance.isAuthenticated) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _openAccount(context),
                child: const Text('Ya tengo una cuenta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
