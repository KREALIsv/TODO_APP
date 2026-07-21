import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_breakpoints.dart';
import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../data/settings_repository.dart';
import '../domain/list_background.dart';

/// Grid sizing for the background picker — denser on wider viewports.
abstract final class _FondoGridLayout {
  static const double maxContentWidth = 720;
  static const double minGradientTileWidth = 148;
  static const double minSolidTileWidth = 100;
  static const double minBrandTileWidth = 140;

  static int gradientColumns(double width) {
    final usable = width.clamp(0, maxContentWidth);
    return (usable / minGradientTileWidth).floor().clamp(2, 5);
  }

  static int solidColumns(double width) {
    final usable = width.clamp(0, maxContentWidth);
    return (usable / minSolidTileWidth).floor().clamp(3, 6);
  }

  static int brandColumns(double width) {
    final usable = width.clamp(0, maxContentWidth);
    return (usable / minBrandTileWidth).floor().clamp(2, 4);
  }

  static double gradientAspectRatio(int columns) =>
      columns >= 4 ? 1.65 : columns >= 3 ? 1.55 : 1.45;

  static double solidAspectRatio(int columns) =>
      columns >= 5 ? 0.88 : columns >= 4 ? 0.9 : 0.92;

  static bool useDenseTiles(double width) =>
      AdaptiveBreakpoints.layoutForWidth(width) != AdaptiveLayout.compact;
}

class FondoPickerScreen extends StatelessWidget {
  const FondoPickerScreen({super.key, this.settings});

  final SettingsRepository? settings;

  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fondo de la lista'),
        backgroundColor: AppSurface.panelOverlay(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final selectedId = _settings.listBackgroundId;
          final brightness = Theme.of(context).brightness;

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final compact = _FondoGridLayout.useDenseTiles(width);
              final gradientColumns = _FondoGridLayout.gradientColumns(width);
              final solidColumns = _FondoGridLayout.solidColumns(width);
              final brandColumns = _FondoGridLayout.brandColumns(width);
              final spacing = compact ? 10.0 : 12.0;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _FondoGridLayout.maxContentWidth,
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, compact ? 24 : 36),
                    children: [
                      _SectionHeader(
                        title: 'Colores',
                        subtitle: 'Degradados suaves para la lista',
                        textTheme: textTheme,
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      GridView.count(
                        crossAxisCount: gradientColumns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: _FondoGridLayout.gradientAspectRatio(
                          gradientColumns,
                        ),
                        children: [
                          _DefaultTile(
                            compact: compact,
                            selected: selectedId == ListBackgrounds.defaultId,
                            accent: ListBackgrounds.predeterminado
                                .resolveAccent(brightness),
                            onTap: () => _settings.setListBackgroundId(
                              ListBackgrounds.defaultId,
                            ),
                          ),
                          for (final option in ListBackgrounds.gradients)
                            _GradientTile(
                              compact: compact,
                              option: option,
                              selected: selectedId == option.id,
                              brightness: brightness,
                              onTap: () =>
                                  _settings.setListBackgroundId(option.id),
                            ),
                        ],
                      ),
                      SizedBox(height: compact ? 20 : 28),
                      _SectionHeader(
                        title: 'Texturas',
                        subtitle: 'Fotos suaves teñidas con cada tono',
                        textTheme: textTheme,
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      GridView.count(
                        crossAxisCount: solidColumns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: _FondoGridLayout.solidAspectRatio(
                          solidColumns,
                        ),
                        children: [
                          for (final option in ListBackgrounds.solids)
                            _SolidTile(
                              compact: compact,
                              option: option,
                              selected: selectedId == option.id,
                              brightness: brightness,
                              onTap: () =>
                                  _settings.setListBackgroundId(option.id),
                            ),
                        ],
                      ),
                      SizedBox(height: compact ? 20 : 28),
                      _SectionHeader(
                        title: 'Marca',
                        subtitle: 'Fondos ilustrados de la ranita',
                        textTheme: textTheme,
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      GridView.count(
                        crossAxisCount: brandColumns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: 1.35,
                        children: [
                          _BrandTile(
                            compact: compact,
                            label: 'Rosa',
                            accent: ListBackgrounds.brandRosa
                                .resolveAccent(brightness),
                            selected: selectedId == ListBackgrounds.brandRosaId,
                            child: Image.asset(
                              ListBackgrounds.rosaAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFFF2327D)),
                            ),
                            onTap: () => _settings.setListBackgroundId(
                              ListBackgrounds.brandRosaId,
                            ),
                          ),
                          _BrandTile(
                            compact: compact,
                            label: 'Verde',
                            accent: ListBackgrounds.brandVerde
                                .resolveAccent(brightness),
                            selected:
                                selectedId == ListBackgrounds.brandVerdeId,
                            child: ColoredBox(
                              color: AppColors.primary00,
                              child: Center(
                                child: Image.asset(
                                  ListBackgrounds.frogAsset,
                                  width: compact ? 56 : 78,
                                  height: compact ? 56 : 78,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            onTap: () => _settings.setListBackgroundId(
                              ListBackgrounds.brandVerdeId,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.textTheme,
  });

  final String title;
  final String subtitle;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.neutral60,
          ),
        ),
      ],
    );
  }
}

class _SelectionFrame extends StatelessWidget {
  const _SelectionFrame({
    required this.selected,
    required this.accent,
    required this.child,
    this.compact = false,
  });

  final bool selected;
  final Color accent;
  final Widget child;
  final bool compact;

  double get _radius => compact ? 12 : 16;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: selected ? accent : AppColors.neutral20.withValues(alpha: 0.7),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: compact ? 6 : 10,
                  offset: Offset(0, compact ? 2 : 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (selected)
              Positioned(
                top: compact ? 5 : 8,
                right: compact ? 5 : 8,
                child: _CheckBadge(accent: accent, compact: compact),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.accent, this.compact = false});

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 18.0 : 22.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: compact ? 1.2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(Icons.check, size: compact ? 11 : 13, color: Colors.white),
    );
  }
}

class _DefaultTile extends StatelessWidget {
  const _DefaultTile({
    required this.selected,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: _SelectionFrame(
        selected: selected,
        accent: accent,
        compact: compact,
        child: Builder(
          builder: (context) {
            final soft = Theme.of(context).colorScheme.primaryContainer;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.neutral00,
                    soft.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: compact ? 14 : 18,
                      color: accent,
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      'Predeterminado',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral100,
                        fontSize: compact ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GradientTile extends StatelessWidget {
  const _GradientTile({
    required this.option,
    required this.selected,
    required this.brightness,
    required this.onTap,
    this.compact = false,
  });

  final ListBackgroundOption option;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = option.resolveGradient(brightness) ??
        [AppColors.neutral00, AppColors.neutral20];
    final accent = option.resolveAccent(brightness);
    final darkLabel = option.prefersDarkLabel && brightness == Brightness.light;
    final labelColor = darkLabel ? AppColors.neutral100 : Colors.white;
    final labelSize = compact ? 11.0 : 13.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: _SelectionFrame(
        selected: selected,
        accent: accent,
        compact: compact,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (darkLabel)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x33000000),
                      ],
                    ),
                  ),
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x40000000),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(compact ? 8 : 12),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    '${option.emoji ?? ''} ${option.label}'.trim(),
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: labelSize,
                      shadows: darkLabel
                          ? null
                          : const [
                              Shadow(blurRadius: 6, color: Colors.black38),
                            ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolidTile extends StatelessWidget {
  const _SolidTile({
    required this.option,
    required this.selected,
    required this.brightness,
    required this.onTap,
    this.compact = false,
  });

  final ListBackgroundOption option;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = option.resolveSolid(brightness);
    final accent = option.resolveAccent(brightness);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SelectionFrame(
              selected: selected,
              accent: accent,
              compact: compact,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (option.hasAsset)
                    Image.asset(
                      option.assetPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: tint),
                    )
                  else
                    ColoredBox(color: tint),
                  ColoredBox(color: tint.withValues(alpha: 0.55)),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            option.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: compact ? 10 : 12,
              color: selected ? accent : AppColors.neutral80,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({
    required this.label,
    required this.accent,
    required this.selected,
    required this.child,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final Color accent;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            child: _SelectionFrame(
              selected: selected,
              accent: accent,
              compact: compact,
              child: child,
            ),
          ),
        ),
        SizedBox(height: compact ? 5 : 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: compact ? 11 : 14,
            color: selected ? accent : AppColors.neutral100,
          ),
        ),
      ],
    );
  }
}
