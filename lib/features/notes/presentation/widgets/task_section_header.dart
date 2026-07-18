import 'package:flutter/material.dart';

import '../../domain/task_groups.dart';
import 'today_progress_badge.dart';

class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.title,
    this.progress,
    this.onTap,
    this.trailing,
  });

  final String title;
  final TodayProgress? progress;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: textTheme.headlineSmall),
          ),
          if (progress != null) TodayProgressBadge(progress: progress!),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}
