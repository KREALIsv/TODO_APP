import 'package:flutter/material.dart';

import '../../../global/themes/app_colors.dart';
import '../data/settings_repository.dart';
import '../domain/list_background.dart';

class FondoPickerScreen extends StatelessWidget {
  const FondoPickerScreen({super.key, this.settings});

  final SettingsRepository? settings;

  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fondo de la lista'),
        backgroundColor: isDark ? const Color(0xFF1C2128) : AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final selectedId = _settings.listBackgroundId;
          final brightness = Theme.of(context).brightness;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              _SectionHeader(
                title: 'Colores',
                subtitle: 'Degradados suaves para la lista',
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _DefaultTile(
                    selected: selectedId == ListBackgrounds.defaultId,
                    accent: ListBackgrounds.predeterminado
                        .resolveAccent(brightness),
                    onTap: () => _settings
                        .setListBackgroundId(ListBackgrounds.defaultId),
                  ),
                  for (final option in ListBackgrounds.gradients)
                    _GradientTile(
                      option: option,
                      selected: selectedId == option.id,
                      brightness: brightness,
                      onTap: () => _settings.setListBackgroundId(option.id),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Texturas',
                subtitle: 'Fotos suaves teñidas con cada tono',
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
                children: [
                  for (final option in ListBackgrounds.solids)
                    _SolidTile(
                      option: option,
                      selected: selectedId == option.id,
                      brightness: brightness,
                      onTap: () => _settings.setListBackgroundId(option.id),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Marca',
                subtitle: 'Fondos ilustrados de la ranita',
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BrandTile(
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
                      onTap: () => _settings
                          .setListBackgroundId(ListBackgrounds.brandRosaId),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BrandTile(
                      label: 'Verde',
                      accent: ListBackgrounds.brandVerde
                          .resolveAccent(brightness),
                      selected: selectedId == ListBackgrounds.brandVerdeId,
                      child: ColoredBox(
                        color: AppColors.primary00,
                        child: Center(
                          child: Image.asset(
                            ListBackgrounds.frogAsset,
                            width: 78,
                            height: 78,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      onTap: () => _settings
                          .setListBackgroundId(ListBackgrounds.brandVerdeId),
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
  });

  final bool selected;
  final Color accent;
  final Widget child;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: selected ? accent : AppColors.neutral20.withValues(alpha: 0.7),
          width: selected ? 2.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
                top: 8,
                right: 8,
                child: _CheckBadge(accent: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.check, size: 13, color: Colors.white),
    );
  }
}

class _DefaultTile extends StatelessWidget {
  const _DefaultTile({
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _SelectionFrame(
        selected: selected,
        accent: accent,
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 18, color: accent),
                    const SizedBox(height: 6),
                    const Text(
                      'Predeterminado',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral100,
                        fontSize: 13,
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
  });

  final ListBackgroundOption option;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = option.resolveGradient(brightness) ??
        [AppColors.neutral00, AppColors.neutral20];
    final accent = option.resolveAccent(brightness);
    final darkLabel = option.prefersDarkLabel && brightness == Brightness.light;
    final labelColor = darkLabel ? AppColors.neutral100 : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _SelectionFrame(
        selected: selected,
        accent: accent,
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
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    '${option.emoji ?? ''} ${option.label}'.trim(),
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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
  });

  final ListBackgroundOption option;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = option.resolveSolid(brightness);
    final accent = option.resolveAccent(brightness);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SelectionFrame(
              selected: selected,
              accent: accent,
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
          const SizedBox(height: 6),
          Text(
            option.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12,
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
  });

  final String label;
  final Color accent;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.35,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: _SelectionFrame(
              selected: selected,
              accent: accent,
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? accent : AppColors.neutral100,
          ),
        ),
      ],
    );
  }
}
