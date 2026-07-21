import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel({
    super.key,
    required this.label,
    required this.textTheme,
    this.accent,
  });

  final String label;
  final TextTheme textTheme;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.neutral60;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(
          color: color.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSurface.cardDecoration(context),
      child: Column(children: children),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppSurface.divider(context),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.trailingWidget,
    this.onTap,
    this.showChevron = true,
    this.iconColor,
    this.titleColor,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? iconColor;
  final Color? titleColor;

  /// Harmonized ink from the active list background.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resolvedIcon =
        iconColor ?? accent ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: resolvedIcon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: titleColor ?? AppSurface.title(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget!,
              const SizedBox(width: 8),
            ] else if (trailing != null) ...[
              Text(
                trailing!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.neutral60,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (showChevron && onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.neutral40,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared radio bottom sheet used by settings pickers (theme, heatmap, …).
Future<T?> showSettingsRadioSheet<T>({
  required BuildContext context,
  required String title,
  required T groupValue,
  required List<(T value, String label)> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            RadioGroup<T>(
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) Navigator.pop(sheetContext, v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    RadioListTile<T>(
                      title: Text(option.$2),
                      value: option.$1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
