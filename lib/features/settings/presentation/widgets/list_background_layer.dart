import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/settings_repository.dart';
import '../../domain/list_background.dart';

/// Renders the selected list background behind opaque cards.
class ListBackgroundLayer extends StatelessWidget {
  const ListBackgroundLayer({
    super.key,
    this.settings,
  });

  final SettingsRepository? settings;

  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final option = _settings.listBackground;
        final brightness = Theme.of(context).brightness;
        return _buildDecoration(option, brightness);
      },
    );
  }

  Widget _buildDecoration(ListBackgroundOption option, Brightness brightness) {
    switch (option.kind) {
      case ListBackgroundKind.solid:
        if (option.hasAsset) {
          return _TintedAssetBackground(
            assetPath: option.assetPath!,
            tint: option.resolveSolid(brightness),
            washOpacity: brightness == Brightness.dark ? 0.72 : 0.58,
          );
        }
        return ColoredBox(color: option.resolveSolid(brightness));
      case ListBackgroundKind.gradient:
        final colors = option.resolveGradient(brightness) ??
            [option.resolveSolid(brightness), option.resolveSolid(brightness)];
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        );
      case ListBackgroundKind.brandRosa:
        return Image.asset(
          ListBackgrounds.rosaAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFFF2327D)),
        );
      case ListBackgroundKind.brandVerde:
        return ColoredBox(
          color: AppColors.primary00,
          child: Center(
            child: Opacity(
              opacity: 0.28,
              child: Image.asset(
                ListBackgrounds.frogAsset,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
    }
  }
}

/// Soft photo texture washed with a brand-safe tint so cards stay readable.
class _TintedAssetBackground extends StatelessWidget {
  const _TintedAssetBackground({
    required this.assetPath,
    required this.tint,
    required this.washOpacity,
  });

  final String assetPath;
  final Color tint;
  final double washOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(color: tint),
        ),
        ColoredBox(color: tint.withValues(alpha: washOpacity)),
      ],
    );
  }
}

/// Wraps [child] with the reactive list background behind it.
class ListBackgroundScaffoldBody extends StatelessWidget {
  const ListBackgroundScaffoldBody({
    super.key,
    required this.child,
    this.settings,
  });

  final Widget child;
  final SettingsRepository? settings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Instant theme underpaint so route pops never flash blank white
        // while the decorative background / list paint catch up.
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        Positioned.fill(
          child: ListBackgroundLayer(settings: settings),
        ),
        child,
      ],
    );
  }
}
