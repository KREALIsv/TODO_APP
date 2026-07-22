import 'package:flutter/material.dart';

import '../../../../core/layout/adaptive_breakpoints.dart';
import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';
import '../../../notes/domain/tag_colors.dart';

/// Branded auth backdrop aligned with boot splash / landing.
class AuthBrandedBackground extends StatelessWidget {
  const AuthBrandedBackground({super.key, required this.child});

  final Widget child;

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
          child,
        ],
      ),
    );
  }
}

/// Centers auth content in a card — narrow on desktop, fluid on mobile.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  static const _logoAsset = 'assets/images/app_icon.png';
  static const _maxContentWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWide =
        AdaptiveBreakpoints.layoutOf(context) != AdaptiveLayout.compact;
    final horizontalPadding = isWide ? 32.0 : 20.0;

    return AuthBrandedBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isWide ? 32 : 16,
              horizontalPadding,
              32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null) ...[
                    Align(alignment: Alignment.centerLeft, child: leading!),
                    const SizedBox(height: 8),
                  ],
                  _AuthHeroHeader(
                    title: title,
                    subtitle: subtitle,
                    textTheme: textTheme,
                    compact: !isWide,
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppSurface.card(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppSurface.border(context).withValues(alpha: 0.65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TagColors.brandPink.withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 28 : 20,
                        isWide ? 28 : 22,
                        isWide ? 28 : 20,
                        isWide ? 28 : 22,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeroHeader extends StatelessWidget {
  const _AuthHeroHeader({
    required this.title,
    required this.subtitle,
    required this.textTheme,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final TextTheme textTheme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 64.0 : 72.0;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: TagColors.brandPink.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              AuthPageShell._logoAsset,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: compact ? 14 : 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppSurface.title(context),
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppSurface.secondary(context),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Primary auth CTA — full width, comfortable height.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Compact banner for remembered account hint.
class AuthInfoBanner extends StatelessWidget {
  const AuthInfoBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary00.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary20.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
