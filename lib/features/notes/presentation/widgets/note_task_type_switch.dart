import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';

/// Toggle nota ↔ tarea (mismo control en compose y editor).
class NoteTaskTypeSwitch extends StatelessWidget {
  const NoteTaskTypeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: 0.05),
      borderRadius: ThemeTokens.borderRadius,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text('Es una tarea', style: textTheme.labelLarge),
        subtitle: Text(
          'Muestra un checkbox en la lista',
          style: textTheme.bodySmall,
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
