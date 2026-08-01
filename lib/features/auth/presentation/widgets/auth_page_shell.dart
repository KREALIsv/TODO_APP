import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    this.footer,
    this.compactHeader = false,
    this.maxContentWidth = 420,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? footer;
  final bool compactHeader;
  final double maxContentWidth;

  static const _logoAsset = 'assets/images/app_icon.png';

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
              constraints: BoxConstraints(maxWidth: maxContentWidth),
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
                    dense: compactHeader,
                  ),
                  SizedBox(height: compactHeader ? 14 : 20),
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
                        isWide ? 28 : 18,
                        isWide ? 28 : 20,
                        isWide ? 28 : 18,
                        isWide ? 28 : 20,
                      ),
                      child: child,
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    footer!,
                  ],
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
    required this.dense,
  });

  final String title;
  final String subtitle;
  final TextTheme textTheme;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final logoSize = dense ? 52.0 : (compact ? 64.0 : 72.0);

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dense ? 14 : 18),
            boxShadow: [
              BoxShadow(
                color: TagColors.brandPink.withValues(alpha: 0.2),
                blurRadius: dense ? 14 : 20,
                offset: Offset(0, dense ? 5 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(dense ? 14 : 18),
            child: Image.asset(
              AuthPageShell._logoAsset,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: dense ? 10 : (compact ? 14 : 16)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: (dense ? textTheme.titleLarge : textTheme.headlineSmall)
              ?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppSurface.title(context),
            letterSpacing: -0.02,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: dense ? 4 : 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: (dense ? textTheme.bodySmall : textTheme.bodyMedium)
                ?.copyWith(
              color: AppSurface.secondary(context),
              height: 1.4,
            ),
          ),
        ],
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

/// Horizontal rule with centered label (e.g. «o»).
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppSurface.border(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppSurface.secondary(context),
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: style),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

/// Secondary auth action shown below the card.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Login/register CTA to open QR pairing on another device.
class AuthPairingOption extends StatelessWidget {
  const AuthPairingOption({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.primary.withValues(alpha: 0.07),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrar con otro dispositivo',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Muestra un QR y apruébalo desde un equipo con sesión.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppSurface.secondary(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-line hint for QR pairing flow.
class AuthPairingHint extends StatelessWidget {
  const AuthPairingHint({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phonelink_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'En el otro dispositivo: Ajustes → Vincular dispositivo → '
              'escanea el QR o introduce el código.',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive QR + manual code block for pairing screens.
class AuthPairingQrPanel extends StatelessWidget {
  const AuthPairingQrPanel({
    super.key,
    required this.qrData,
    required this.displayCode,
    required this.onCopy,
  });

  final String qrData;
  final String displayCode;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxWidth - 4).clamp(248.0, 320.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppSurface.border(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: qrSize,
                    backgroundColor: Colors.white,
                    gapless: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'O introduce este código',
              textAlign: TextAlign.center,
              style: textTheme.labelMedium?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              displayCode,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                letterSpacing: 5,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: AppSurface.title(context),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Copiar'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Polling status while waiting for pairing approval.
class AuthWaitingBanner extends StatelessWidget {
  const AuthWaitingBanner({super.key, required this.remainingLabel});

  final String remainingLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esperando aprobación…',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'El código vence en $remainingLabel',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
