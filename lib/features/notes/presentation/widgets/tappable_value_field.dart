import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';

/// Campo de solo lectura con aspecto de input (fecha, hora, etc.).
class TappableValueField extends StatelessWidget {
  const TappableValueField({
    super.key,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
    this.trailing,
  });

  final String value;
  final VoidCallback onTap;
  final bool isPlaceholder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: ThemeTokens.borderRadius,
        side: BorderSide(color: AppColors.neutral20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: ThemeTokens.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isPlaceholder
                        ? AppColors.neutral40
                        : AppColors.neutral100,
                  ),
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.expand_more,
                size: 22,
                color: AppColors.neutral60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
