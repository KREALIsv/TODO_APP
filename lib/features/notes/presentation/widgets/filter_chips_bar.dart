import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../domain/notes_filter.dart';

class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final NotesFilter activeFilter;
  final ValueChanged<NotesFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: NotesFilter.values.map((filter) {
          final isSelected = filter == activeFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onFilterChanged(filter),
              selectedColor: scheme.primaryContainer,
              side: BorderSide(
                color: isSelected ? scheme.primary : AppColors.neutral20,
              ),
              labelStyle: TextStyle(
                color: isSelected ? scheme.primary : AppColors.neutral80,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
