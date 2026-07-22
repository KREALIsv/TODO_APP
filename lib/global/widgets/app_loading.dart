import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_surface.dart';

/// Compact inline spinner for buttons / inline busy states.
class AppLoading extends StatelessWidget {
  const AppLoading({
    super.key,
    this.size = 20,
    this.strokeWidth = 2,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Full-screen / fill loading surface that matches theme (never blank white).
///
/// Prefer fixing slow work over showing this; use it only when a wait is
/// unavoidable (first load, long import, etc.).
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({
    super.key,
    this.message,
    this.backgroundColor,
  });

  final String? message;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: backgroundColor ?? scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoading(size: 28, strokeWidth: 2.5),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Decodes [bytes] at display resolution so list/detail transitions stay snappy.
///
/// Always paints [placeholderColor] underneath so cache misses never flash
/// an empty/white hole.
class AppMemoryImage extends StatelessWidget {
  const AppMemoryImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholderColor,
    this.filterQuality = FilterQuality.low,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Color? placeholderColor;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        width != null ? (width! * dpr).round().clamp(1, 4096) : null;
    final cacheHeight =
        height != null ? (height! * dpr).round().clamp(1, 4096) : null;

    return ColoredBox(
      color: placeholderColor ?? AppSurface.card(context),
      child: Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
      ),
    );
  }
}
