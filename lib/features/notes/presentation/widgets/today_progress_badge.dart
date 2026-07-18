import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/task_groups.dart';

class TodayProgressBadge extends StatelessWidget {
  const TodayProgressBadge({super.key, required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context) {
    if (progress.hideIfZero) return const SizedBox.shrink();

    final complete = progress.isComplete;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: complete ? AppColors.primary : AppColors.primary00,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${progress.done}/${progress.total} done',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: complete ? AppColors.white : AppColors.primary80,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
