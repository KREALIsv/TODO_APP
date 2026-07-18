import 'package:flutter/material.dart';

import '../../domain/tag_colors.dart';

class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.colors,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.expanded = false,
    this.compact = false,
  });

  final String label;
  final TagColorPair? colors;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  /// Si es true, la pastilla ocupa el ancho disponible (lista tipo Trello).
  final bool expanded;

  /// Versión densa (p. ej. cards). Si es false, usa el tamaño del texto de input.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pair = colors ?? TagColors.colorForTag(label);
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(compact ? 8 : 10);

    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: expanded ? TextAlign.center : TextAlign.start,
      style: (compact ? textTheme.labelSmall : textTheme.bodyLarge)?.copyWith(
        color: pair.foreground,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.2,
      ),
    );

    final content = Padding(
      padding: EdgeInsets.only(
        left: compact ? 10 : 12,
        right: onDelete != null ? (compact ? 4 : 6) : (compact ? 10 : 12),
        top: compact ? 5 : 8,
        bottom: compact ? 5 : 8,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (expanded) Expanded(child: labelWidget) else labelWidget,
          if (onDelete != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: compact ? 14 : 18,
                color: pair.foreground,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: pair.background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}
