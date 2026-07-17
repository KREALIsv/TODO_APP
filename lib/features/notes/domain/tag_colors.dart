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

class TagColors {
  TagColors._();

  static const List<TagColorPair> palette = [
    TagColorPair(
      background: AppColors.primary00,
      foreground: AppColors.primary80,
    ),
    TagColorPair(
      background: AppColors.secondary00,
      foreground: AppColors.secondary80,
    ),
    TagColorPair(
      background: AppColors.tertiary15,
      foreground: AppColors.primary80,
    ),
    TagColorPair(
      background: AppColors.neutral00,
      foreground: AppColors.neutral80,
    ),
    TagColorPair(
      background: AppColors.primary20,
      foreground: AppColors.primary80,
    ),
    TagColorPair(
      background: AppColors.secondary20,
      foreground: AppColors.secondary80,
    ),
  ];

  static TagColorPair colorForTag(String tag) {
    final hash = tag.toLowerCase().hashCode.abs();
    return palette[hash % palette.length];
  }
}
