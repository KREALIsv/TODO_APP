import 'package:flutter/material.dart';

import 'app_loading.dart';

/// Branded full-screen splash (logo + spinner). Used on native while Hive
/// opens; on web the HTML shell covers boot until [notifyWebAppReady].
class AppBootSplash extends StatelessWidget {
  const AppBootSplash({
    super.key,
    this.message = 'Cargando…',
  });

  final String message;

  static const _logoAsset = 'assets/images/app_icon.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                _logoAsset,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 24),
            AppLoading(
              size: 28,
              strokeWidth: 2.5,
              color: scheme.primary,
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
