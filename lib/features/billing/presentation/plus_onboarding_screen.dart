import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_screen.dart';
import '../data/subscription_service.dart';
import '../domain/plus_plan.dart';

class PlusOnboardingScreen extends StatefulWidget {
  const PlusOnboardingScreen({super.key, this.placement = 'settings'});

  final String placement;

  @override
  State<PlusOnboardingScreen> createState() => _PlusOnboardingScreenState();
}

class _PlusOnboardingScreenState extends State<PlusOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  PlusPlan _selectedPlan = PlusPlan.annual;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (!AuthService.instance.isAuthenticated) {
      final authenticated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const AuthScreen(
            contextTitle: 'Guarda tu progreso',
            contextMessage:
                'Crea tu cuenta WODO para vincular el plan y sincronizar tus datos de forma segura.',
          ),
        ),
      );
      if (authenticated != true || !mounted) return;
    }

    setState(() => _submitting = true);
    final result = await SubscriptionService.instance.beginCheckout(
      _selectedPlan.id,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == BillingActionResult.unavailable) {
      await AppAlerts.show(
        context,
        message:
            'La compra con Polar se habilitará pronto. Tu cuenta ya está lista.',
        type: AppAlertType.info,
      );
    }
  }

  Future<void> _restore() async {
    if (!AuthService.instance.isAuthenticated) {
      await AppAlerts.show(
        context,
        message:
            'Inicia sesión para restaurar una compra vinculada a tu cuenta.',
        type: AppAlertType.info,
      );
      return;
    }
    final result = await SubscriptionService.instance.restore();
    if (!mounted) return;
    await AppAlerts.show(
      context,
      message: result == BillingActionResult.restored
          ? 'Tu plan fue restaurado.'
          : 'La restauración estará disponible al conectar Polar.',
      type: result == BillingActionResult.restored
          ? AppAlertType.success
          : AppAlertType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WODO Plus'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                  child: Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 4,
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                          decoration: BoxDecoration(
                            color: index <= _page
                                ? scheme.primary
                                : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    children: [
                      const _BenefitPage(
                        icon: Icons.cloud_done_outlined,
                        eyebrow: 'RESPALDO AUTOMÁTICO',
                        title: 'Tus ideas, protegidas',
                        message:
                            'WODO guarda una copia segura en la nube sin cambiar la forma rápida y local en que trabajas.',
                        bullets: [
                          'Sigue escribiendo aunque no tengas conexión',
                          'Recupera tus datos al cambiar de dispositivo',
                          'Historial recuperable durante 30 días',
                        ],
                      ),
                      const _BenefitPage(
                        icon: Icons.devices_outlined,
                        eyebrow: 'CONTINUIDAD',
                        title: 'Tu WODO va contigo',
                        message:
                            'Empieza una nota en la computadora y continúa desde el teléfono, con hasta 5 dispositivos vinculados.',
                        bullets: [
                          'Web, Android e iOS',
                          'Sincronización al recuperar conexión',
                          'Tus notas locales nunca se borran en silencio',
                        ],
                      ),
                      _PlansPage(
                        selected: _selectedPlan,
                        onSelected: (plan) =>
                            setState(() => _selectedPlan = plan),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _submitting ? null : _next,
                        child: Text(
                          _page < 2
                              ? 'Continuar'
                              : AuthService.instance.isAuthenticated
                              ? 'Continuar con ${_selectedPlan.title.toLowerCase()}'
                              : 'Crear cuenta y continuar',
                        ),
                      ),
                      if (_page == 2)
                        TextButton(
                          onPressed: _submitting ? null : _restore,
                          child: const Text('Restaurar compra'),
                        )
                      else
                        TextButton(
                          onPressed: () => _controller.animateToPage(
                            2,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                          child: const Text('Ver planes'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitPage extends StatelessWidget {
  const _BenefitPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.bullets,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      children: [
        Align(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: scheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          eyebrow,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: AppSurface.secondary(context),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        ...bullets.map(
          (bullet) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 21, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(bullet, style: textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlansPage extends StatelessWidget {
  const _PlansPage({required this.selected, required this.onSelected});

  final PlusPlan selected;
  final ValueChanged<PlusPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      children: [
        Text(
          'Elige cómo cuidar tus datos',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '14 días para probar Plus. Cancela cuando quieras.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppSurface.secondary(context),
          ),
        ),
        const SizedBox(height: 24),
        for (final plan in PlusPlan.all) ...[
          _PlanCard(
            plan: plan,
            selected: selected.id == plan.id,
            onTap: () => onSelected(plan),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(
          'Incluye sincronización, respaldo automático y recuperación de 30 días. La renovación será automática cuando se habiliten los pagos.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: AppSurface.secondary(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PlusPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : AppSurface.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : AppSurface.border(context),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? scheme.primary
                    : AppSurface.secondary(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          plan.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (plan.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              plan.badge!,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.priceDetail,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppSurface.secondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                plan.price,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
