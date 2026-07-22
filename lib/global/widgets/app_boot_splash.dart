import 'package:flutter/material.dart';

import '../../features/notes/domain/tag_colors.dart';
import '../../global/themes/app_colors.dart';

/// Branded full-screen splash (logo + loader). Used on native while Hive
/// opens; on web the HTML shell covers boot until [notifyWebAppReady].
class AppBootSplash extends StatefulWidget {
  const AppBootSplash({
    super.key,
    this.message = 'Cargando',
  });

  final String message;

  static const _logoAsset = 'assets/images/app_icon.png';

  @override
  State<AppBootSplash> createState() => _AppBootSplashState();
}

class _AppBootSplashState extends State<AppBootSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _AppBootBackground(),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: TagColors.brandPink.withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            AppBootSplash._logoAsset,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'WODO',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.4,
                          color: AppColors.neutral60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _AppBootDotLoader(),
                if (widget.message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutral60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppBootBackground extends StatelessWidget {
  const _AppBootBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.neutral00,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.85),
                radius: 1.1,
                colors: [
                  TagColors.brandPink.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 0.9),
                radius: 0.75,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.85, 0.75),
                radius: 0.7,
                colors: [
                  AppColors.tertiary.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBootDotLoader extends StatefulWidget {
  const _AppBootDotLoader();

  @override
  State<_AppBootDotLoader> createState() => _AppBootDotLoaderState();
}

class _AppBootDotLoaderState extends State<_AppBootDotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = (_controller.value + index * 0.2) % 1.0;
              final scale = 0.55 + (phase < 0.4 ? phase / 0.4 : (1 - phase) / 0.6) * 0.45;
              final opacity = 0.4 + scale * 0.6;
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
              decoration: const BoxDecoration(
                color: TagColors.brandPink,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
