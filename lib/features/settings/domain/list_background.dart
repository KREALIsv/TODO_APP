import 'package:flutter/material.dart';

import '../../../global/themes/app_colors.dart';

enum ListBackgroundKind { solid, gradient, brandRosa, brandVerde }

class ListBackgroundOption {
  const ListBackgroundOption({
    required this.id,
    required this.label,
    required this.kind,
    this.emoji,
    this.lightColor,
    this.darkColor,
    this.lightGradient,
    this.darkGradient,
    this.assetPath,
    this.lightAccent,
    this.darkAccent,
  });

  final String id;
  final String label;
  final ListBackgroundKind kind;
  final String? emoji;
  final Color? lightColor;
  final Color? darkColor;
  final List<Color>? lightGradient;
  final List<Color>? darkGradient;
  final String? assetPath;

  /// Darker ink that harmonizes with this background (icons, selection).
  final Color? lightAccent;
  final Color? darkAccent;

  bool get isBrand =>
      kind == ListBackgroundKind.brandRosa ||
      kind == ListBackgroundKind.brandVerde;

  bool get hasAsset => assetPath != null && assetPath!.isNotEmpty;

  Color resolveSolid(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return darkColor ?? lightColor ?? AppColors.neutral00;
    }
    return lightColor ?? AppColors.neutral00;
  }

  List<Color>? resolveGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return darkGradient ?? lightGradient;
    }
    return lightGradient;
  }

  /// Accent that stands out on this background without clashing.
  Color resolveAccent(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return darkAccent ?? lightAccent ?? AppColors.primary40;
    }
    return lightAccent ?? AppColors.primary;
  }

  /// Whether label text on a gradient tile should use dark ink.
  bool get prefersDarkLabel {
    if (kind != ListBackgroundKind.gradient || lightGradient == null) {
      return false;
    }
    final luminance = lightGradient!
        .map((c) => c.computeLuminance())
        .reduce((a, b) => a + b) /
        lightGradient!.length;
    return luminance > 0.55;
  }
}

class ListBackgrounds {
  ListBackgrounds._();

  static const defaultId = 'default';
  static const brandRosaId = 'brand_rosa';
  static const brandVerdeId = 'brand_verde';

  static const rosaAsset = 'assets/images/backgrounds/bg_rosa.png';
  static const frogAsset = 'assets/images/app_icon.png';

  static const mentaAsset = 'assets/images/backgrounds/solid_menta.jpg';
  static const arenaAsset = 'assets/images/backgrounds/solid_arena.jpg';
  static const lavandaAsset = 'assets/images/backgrounds/solid_lavanda.jpg';
  static const grisAsset = 'assets/images/backgrounds/solid_gris.jpg';
  static const azulAsset = 'assets/images/backgrounds/solid_azul.jpg';

  static const ListBackgroundOption predeterminado = ListBackgroundOption(
    id: defaultId,
    label: 'Predeterminado',
    kind: ListBackgroundKind.solid,
    lightColor: AppColors.neutral00,
    darkColor: Color(0xFF1C2128),
    lightAccent: AppColors.primary,
    darkAccent: AppColors.primary40,
  );

  static const List<ListBackgroundOption> gradients = [
    ListBackgroundOption(
      id: 'ocean',
      label: 'Océano',
      kind: ListBackgroundKind.gradient,
      emoji: '🌊',
      lightGradient: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
      darkGradient: [Color(0xFF0A2744), Color(0xFF1565C0)],
      lightAccent: Color(0xFF0A3D6B),
      darkAccent: Color(0xFF7EB6E8),
    ),
    ListBackgroundOption(
      id: 'glacier',
      label: 'Glaciar',
      kind: ListBackgroundKind.gradient,
      emoji: '❄️',
      lightGradient: [Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
      darkGradient: [Color(0xFF1A3A4A), Color(0xFF0D2B36)],
      lightAccent: Color(0xFF2F6B7A),
      darkAccent: Color(0xFF8EC8D6),
    ),
    ListBackgroundOption(
      id: 'sakura',
      label: 'Sakura',
      kind: ListBackgroundKind.gradient,
      emoji: '🌸',
      lightGradient: [Color(0xFFF8BBD0), Color(0xFFFFE0B2)],
      darkGradient: [Color(0xFF4A2A38), Color(0xFF3A2A20)],
      lightAccent: Color(0xFFB85A78),
      darkAccent: Color(0xFFE8A0B8),
    ),
    ListBackgroundOption(
      id: 'selva',
      label: 'Selva',
      kind: ListBackgroundKind.gradient,
      emoji: '🌿',
      lightGradient: [Color(0xFF00695C), Color(0xFF66BB6A)],
      darkGradient: [Color(0xFF0D3B34), Color(0xFF1B5E20)],
      lightAccent: Color(0xFF145A40),
      darkAccent: Color(0xFF8FD4A0),
    ),
    ListBackgroundOption(
      id: 'peach',
      label: 'Durazno',
      kind: ListBackgroundKind.gradient,
      emoji: '🍑',
      lightGradient: [Color(0xFFFF8A65), Color(0xFFFFCC80)],
      darkGradient: [Color(0xFF4A2E22), Color(0xFF3D2A18)],
      lightAccent: Color(0xFFC45C2A),
      darkAccent: Color(0xFFFFB074),
    ),
    ListBackgroundOption(
      id: 'aurora',
      label: 'Aurora',
      kind: ListBackgroundKind.gradient,
      emoji: '🌈',
      lightGradient: [Color(0xFFCE93D8), Color(0xFF90CAF9)],
      darkGradient: [Color(0xFF3A2A4A), Color(0xFF1A2A4A)],
      lightAccent: Color(0xFF6B4A9A),
      darkAccent: Color(0xFFC4A0E8),
    ),
  ];

  static const List<ListBackgroundOption> solids = [
    ListBackgroundOption(
      id: 'menta',
      label: 'Menta',
      kind: ListBackgroundKind.solid,
      lightColor: Color(0xFFE0F2F1),
      darkColor: Color(0xFF1A3330),
      assetPath: mentaAsset,
      lightAccent: Color(0xFF2A7A6E),
      darkAccent: Color(0xFF8FD0C4),
    ),
    ListBackgroundOption(
      id: 'arena',
      label: 'Arena',
      kind: ListBackgroundKind.solid,
      lightColor: Color(0xFFF5F0E6),
      darkColor: Color(0xFF2E2A22),
      assetPath: arenaAsset,
      lightAccent: Color(0xFF8B7355),
      darkAccent: Color(0xFFD4C4A8),
    ),
    ListBackgroundOption(
      id: 'lavanda',
      label: 'Lavanda',
      kind: ListBackgroundKind.solid,
      lightColor: Color(0xFFEDE7F6),
      darkColor: Color(0xFF2A2438),
      assetPath: lavandaAsset,
      lightAccent: Color(0xFF6B5B95),
      darkAccent: Color(0xFFC4B0E8),
    ),
    ListBackgroundOption(
      id: 'gris_calido',
      label: 'Gris cálido',
      kind: ListBackgroundKind.solid,
      lightColor: Color(0xFFEEEBE7),
      darkColor: Color(0xFF2A2826),
      assetPath: grisAsset,
      lightAccent: Color(0xFF5A5550),
      darkAccent: Color(0xFFC8C2BA),
    ),
    ListBackgroundOption(
      id: 'azul_suave',
      label: 'Azul suave',
      kind: ListBackgroundKind.solid,
      lightColor: Color(0xFFE3F2FD),
      darkColor: Color(0xFF1A2A38),
      assetPath: azulAsset,
      lightAccent: Color(0xFF3A6B9A),
      darkAccent: Color(0xFFA0C4E8),
    ),
  ];

  static const ListBackgroundOption brandRosa = ListBackgroundOption(
    id: brandRosaId,
    label: 'Rosa',
    kind: ListBackgroundKind.brandRosa,
    assetPath: rosaAsset,
    lightColor: Color(0xFFF2327D),
    darkColor: Color(0xFFF2327D),
    lightAccent: Color(0xFFA0154A),
    darkAccent: Color(0xFFFF8AB8),
  );

  static const ListBackgroundOption brandVerde = ListBackgroundOption(
    id: brandVerdeId,
    label: 'Verde',
    kind: ListBackgroundKind.brandVerde,
    lightColor: AppColors.primary00,
    darkColor: AppColors.primary00,
    lightAccent: AppColors.primary80,
    darkAccent: AppColors.primary40,
  );

  static List<ListBackgroundOption> get all => [
        predeterminado,
        ...gradients,
        ...solids,
        brandRosa,
        brandVerde,
      ];

  static ListBackgroundOption byId(String id) {
    for (final option in all) {
      if (option.id == id) return option;
    }
    return predeterminado;
  }
}
