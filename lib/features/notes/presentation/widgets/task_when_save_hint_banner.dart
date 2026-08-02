import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';

/// Subtle BuJo save preview — one priority message, shown while editing «¿Cuándo?».
class TaskWhenSaveHintBanner extends StatelessWidget {
  const TaskWhenSaveHintBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
                height: 1.35,
              ),
        ),
      ),
    );
  }
}
