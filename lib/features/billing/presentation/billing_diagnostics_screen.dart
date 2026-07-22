import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../settings/presentation/widgets/settings_section.dart';
import '../data/billing_service.dart';

class BillingDiagnosticsScreen extends StatefulWidget {
  const BillingDiagnosticsScreen({super.key, this.service});

  final BillingService? service;

  @override
  State<BillingDiagnosticsScreen> createState() =>
      _BillingDiagnosticsScreenState();
}

class _BillingDiagnosticsScreenState extends State<BillingDiagnosticsScreen> {
  BillingService get _service => widget.service ?? BillingService.instance;

  Future<void> _copyIdentity() async {
    await Clipboard.setData(ClipboardData(text: _service.appUserId));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App User ID copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación de plataforma'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SettingsSectionLabel(
                label: 'Identidad',
                textTheme: textTheme,
                accent: accent,
              ),
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App User ID',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                _service.appUserId,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _copyIdentity,
                          tooltip: 'Copiar identidad',
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsSectionLabel(
                label: 'RevenueCat sandbox',
                textTheme: textTheme,
                accent: accent,
              ),
              SettingsCard(
                children: [
                  _StatusRow(
                    label: 'Plataforma',
                    value: _service.platformLabel,
                  ),
                  const SettingsDivider(),
                  _StatusRow(
                    label: 'Clave pública',
                    value: _service.isConfigured ? 'Configurada' : 'Pendiente',
                    positive: _service.isConfigured,
                  ),
                  const SettingsDivider(),
                  _StatusRow(
                    label: 'Conexión',
                    value: _connectionLabel(_service.state),
                    positive: _service.state == BillingConnectionState.ready,
                  ),
                  const SettingsDivider(),
                  _StatusRow(
                    label: 'Entitlement wodo_plus',
                    value: _service.hasPlus ? 'Activo' : 'No activo',
                    positive: _service.hasPlus,
                  ),
                ],
              ),
              if (_service.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _service.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 20),
              SettingsSectionLabel(
                label: 'Productos',
                textTheme: textTheme,
                accent: accent,
              ),
              if (_service.packages.isEmpty)
                SettingsCard(
                  children: [
                    _StatusRow(
                      label: 'Offering actual',
                      value: _service.isConfigured
                          ? 'Sin productos'
                          : 'Pendiente',
                    ),
                  ],
                )
              else
                SettingsCard(
                  children: [
                    for (
                      var index = 0;
                      index < _service.packages.length;
                      index++
                    ) ...[
                      _PackageRow(
                        package: _service.packages[index],
                        enabled:
                            _service.state != BillingConnectionState.loading,
                        onPurchase: () =>
                            _service.purchase(_service.packages[index].id),
                      ),
                      if (index < _service.packages.length - 1)
                        const SettingsDivider(),
                    ],
                  ],
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _service.state == BillingConnectionState.loading
                          ? null
                          : _service.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _service.state == BillingConnectionState.loading
                          ? null
                          : _service.restore,
                      icon: const Icon(Icons.restore),
                      label: const Text('Restaurar'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _connectionLabel(BillingConnectionState state) {
    return switch (state) {
      BillingConnectionState.unconfigured => 'Sin configurar',
      BillingConnectionState.loading => 'Consultando',
      BillingConnectionState.ready => 'Conectado',
      BillingConnectionState.failed => 'Error',
    };
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.positive = false,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                color: positive ? AppColors.primary : AppColors.neutral60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.package,
    required this.enabled,
    required this.onPurchase,
  });

  final BillingPackage package;
  final bool enabled;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.title, style: textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(package.productId, style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: enabled ? onPurchase : null,
            child: Text(package.price),
          ),
        ],
      ),
    );
  }
}
