import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/task_groups.dart';
import 'today_progress_badge.dart';

class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
    this.expanded,
    this.onToggle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final TodayProgress? progress;
  /// When set, shows a collapse chevron and makes the header tappable.
  final bool? expanded;
  final VoidCallback? onToggle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCollapsible = expanded != null;
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral60,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (progress != null) TodayProgressBadge(progress: progress!),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (isCollapsible) ...[
            const SizedBox(width: 8),
            Icon(
              expanded! ? Icons.expand_less : Icons.expand_more,
              color: AppColors.neutral60,
            ),
          ],
        ],
      ),
    );

    if (isCollapsible && onToggle != null) {
      return InkWell(onTap: onToggle, child: child);
    }
    return child;
  }
}
