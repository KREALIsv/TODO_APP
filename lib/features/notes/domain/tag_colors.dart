import 'package:flutter/material.dart';

import '../../../global/themes/app_colors.dart';

class TagColorPair {
  const TagColorPair({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

/// Swatch seleccionable (id estable para persistir en Hive).
class TagSwatch {
  const TagSwatch({
    required this.id,
    required this.color,
    required this.label,
  });

  final String id;
  final Color color;
  final String label;

  TagColorPair get pair => TagColorPair(
        background: color,
        foreground: TagColors.foregroundFor(color),
      );

  TagColorPair pairWithOpacity(double opacity) =>
      TagColors.pairFromColor(color, opacity: opacity);
}

class TagColors {
  TagColors._();

  /// Rosado del favicon / theme_color (`web/manifest.json`).
  static const Color brandPink = Color(0xFFF2327D);

  static const double minOpacity = 0.2;
  static const double maxOpacity = 1.0;
  static const double defaultOpacity = 1.0;

  static Color foregroundFor(Color background) {
    return background.computeLuminance() > 0.55
        ? AppColors.black
        : AppColors.white;
  }

  static double clampOpacity(double opacity) =>
      opacity.clamp(minOpacity, maxOpacity).toDouble();

  static TagColorPair pairFromColor(Color color, {double opacity = defaultOpacity}) {
    final alpha = clampOpacity(opacity);
    final background = color.withValues(alpha: alpha);
    final blended = Color.alphaBlend(background, AppColors.white);
    return TagColorPair(
      background: background,
      foreground: foregroundFor(blended),
    );
  }

  /// Paleta amplia inspirada en etiquetas tipo Trello + marca de la app.
  static const List<TagSwatch> swatches = [
    // Fila marca
    TagSwatch(id: 'brand_pink', color: brandPink, label: 'Rosa marca'),
    TagSwatch(id: 'brand_green', color: AppColors.primary, label: 'Verde marca'),
    TagSwatch(id: 'frog_mint', color: Color(0xFFB5E8C4), label: 'Menta'),
    TagSwatch(id: 'frog_spot', color: Color(0xFF7CB342), label: 'Lima'),
    TagSwatch(id: 'teal', color: Color(0xFF26A69A), label: 'Verde azulado'),
    TagSwatch(id: 'cyan', color: Color(0xFF4DD0E1), label: 'Cian'),
    // Amarillos / naranjas
    TagSwatch(id: 'yellow', color: Color(0xFFFFEB3B), label: 'Amarillo'),
    TagSwatch(id: 'gold', color: Color(0xFFFFC107), label: 'Dorado'),
    TagSwatch(id: 'amber', color: Color(0xFFFF9800), label: 'Ámbar'),
    TagSwatch(id: 'orange', color: Color(0xFFFF7043), label: 'Naranja'),
    TagSwatch(id: 'coral', color: Color(0xFFFF8A80), label: 'Coral'),
    TagSwatch(id: 'peach', color: Color(0xFFFFAB91), label: 'Durazno'),
    // Rosas / rojos
    TagSwatch(id: 'pink_soft', color: Color(0xFFF48FB1), label: 'Rosa suave'),
    TagSwatch(id: 'magenta', color: Color(0xFFE91E63), label: 'Magenta'),
    TagSwatch(id: 'red', color: Color(0xFFEF5350), label: 'Rojo'),
    TagSwatch(id: 'rose', color: Color(0xFFEC407A), label: 'Rosa'),
    TagSwatch(id: 'berry', color: Color(0xFFAD1457), label: 'Baya'),
    TagSwatch(id: 'maroon', color: Color(0xFFC62828), label: 'Granate'),
    // Morados
    TagSwatch(id: 'lavender', color: Color(0xFFCE93D8), label: 'Lavanda'),
    TagSwatch(id: 'purple', color: Color(0xFFAB47BC), label: 'Morado'),
    TagSwatch(id: 'violet', color: Color(0xFF7E57C2), label: 'Violeta'),
    TagSwatch(id: 'indigo', color: Color(0xFF5C6BC0), label: 'Índigo'),
    TagSwatch(id: 'deep_purple', color: Color(0xFF6A1B9A), label: 'Púrpura'),
    TagSwatch(id: 'plum', color: Color(0xFF8E24AA), label: 'Ciruela'),
    // Azules
    TagSwatch(id: 'sky', color: Color(0xFF81D4FA), label: 'Cielo'),
    TagSwatch(id: 'blue', color: Color(0xFF42A5F5), label: 'Azul'),
    TagSwatch(id: 'royal', color: Color(0xFF1E88E5), label: 'Azul real'),
    TagSwatch(id: 'navy', color: Color(0xFF1565C0), label: 'Azul marino'),
    TagSwatch(id: 'ocean', color: Color(0xFF00838F), label: 'Océano'),
    TagSwatch(id: 'steel', color: Color(0xFF546E7A), label: 'Acero'),
    // Verdes / tierra / neutros
    TagSwatch(id: 'lime', color: Color(0xFFCDDC39), label: 'Lima clara'),
    TagSwatch(id: 'olive', color: Color(0xFF9E9D24), label: 'Oliva'),
    TagSwatch(id: 'forest', color: Color(0xFF2E7D32), label: 'Bosque'),
    TagSwatch(id: 'sage', color: Color(0xFFA5D6A7), label: 'Salvia'),
    TagSwatch(id: 'sand', color: Color(0xFFD7CCC8), label: 'Arena'),
    TagSwatch(id: 'gray', color: Color(0xFF90A4AE), label: 'Gris'),
  ];

  /// Compat: pares derivados de la paleta (tests / fallback).
  static List<TagColorPair> get palette =>
      swatches.map((s) => s.pair).toList(growable: false);

  static TagSwatch? byId(String id) {
    for (final s in swatches) {
      if (s.id == id) return s;
    }
    return null;
  }

  static String defaultIdForTag(String tag) {
    final hash = tag.toLowerCase().hashCode.abs();
    return swatches[hash % swatches.length].id;
  }

  static TagColorPair colorForTag(String tag, {double opacity = defaultOpacity}) {
    final swatch = byId(defaultIdForTag(tag))!;
    return swatch.pairWithOpacity(opacity);
  }

  static TagColorPair pairForId(
    String? id, {
    String? fallbackTag,
    double opacity = defaultOpacity,
  }) {
    final swatch = id == null ? null : byId(id);
    if (swatch != null) return swatch.pairWithOpacity(opacity);
    if (fallbackTag != null) {
      return colorForTag(fallbackTag, opacity: opacity);
    }
    return swatches.first.pairWithOpacity(opacity);
  }
}
