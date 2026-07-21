import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';

/// Shared top chrome for desktop shell columns — matches [SliverAppBar] height.
class DesktopColumnHeader extends StatelessWidget implements PreferredSizeWidget {
  const DesktopColumnHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.centerTitle = false,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool centerTitle;

  static const double toolbarHeight = kToolbarHeight;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: AppSurface.panelOverlay(context),
          child: SizedBox(
            height: toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  leading ?? const SizedBox(width: 8),
                  Expanded(
                    child: centerTitle
                        ? Center(child: titleWidget)
                        : titleWidget,
                  ),
                  trailing ?? const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        Container(height: 1, color: AppSurface.divider(context)),
      ],
    );
  }
}
