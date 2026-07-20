import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../themes/tokens.dart';

enum AppAlertType { info, success, warning, error }

/// API centralizado para alertas y confirmaciones modales.
class AppAlerts {
  AppAlerts._();

  static Future<void> show(
    BuildContext context, {
    required String message,
    String? title,
    AppAlertType type = AppAlertType.info,
    String confirmLabel = 'Entendido',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _AppAlertDialog(
        title: title ?? _defaultTitle(type),
        message: message,
        type: type,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String message,
    String? title,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AppAlertDialog(
        title: title ?? 'Confirmar',
        message: message,
        type: isDestructive ? AppAlertType.error : AppAlertType.warning,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Modal con acción secundaria (p. ej. Deshacer) + cierre.
  static Future<void> showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    String? title,
    AppAlertType type = AppAlertType.info,
    String dismissLabel = 'Cerrar',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _AppAlertDialog(
        title: title ?? _defaultTitle(type),
        message: message,
        type: type,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onAction();
            },
            child: Text(actionLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dismissLabel),
          ),
        ],
      ),
    );
  }

  static String _defaultTitle(AppAlertType type) {
    return switch (type) {
      AppAlertType.info => 'Aviso',
      AppAlertType.success => 'Listo',
      AppAlertType.warning => 'Atención',
      AppAlertType.error => 'Error',
    };
  }
}

class _AppAlertDialog extends StatelessWidget {
  const _AppAlertDialog({
    required this.title,
    required this.message,
    required this.type,
    required this.actions,
  });

  final String title;
  final String message;
  final AppAlertType type;
  final List<Widget> actions;

  IconData get _icon => switch (type) {
        AppAlertType.info => Icons.info_outline,
        AppAlertType.success => Icons.check_circle_outline,
        AppAlertType.warning => Icons.warning_amber_rounded,
        AppAlertType.error => Icons.error_outline,
      };

  Color _accentFor(BuildContext context) => switch (type) {
        AppAlertType.info => Theme.of(context).colorScheme.primary,
        AppAlertType.success => Theme.of(context).colorScheme.primary,
        AppAlertType.warning => const Color(0xFFBF8700),
        AppAlertType.error => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = _accentFor(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: ThemeTokens.borderRadius,
      ),
      backgroundColor: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_icon, color: accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
