import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Outlined “+ label” chip used by tags and attachments empty CTAs.
class OutlinedAddChip extends StatelessWidget {
  const OutlinedAddChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// true: icon only (chips already in the row).
  /// false: pill with [label] text.
  final bool compact;

  /// Same radius as [TagPill] in the editor (`compact: false` → 10).
  static final radius = BorderRadius.circular(10);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null;

    final child = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.neutral00,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.neutral20),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.neutral60),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.neutral60,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (compact) {
      return Tooltip(message: label, child: child);
    }
    return child;
  }
}
