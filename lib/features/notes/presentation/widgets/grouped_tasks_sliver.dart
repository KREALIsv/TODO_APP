import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_groups.dart';
import 'swipeable_note_card.dart';
import 'task_section_header.dart';

/// Builds slivers for grouped tasks (Hoy / Próximas / Sin fecha / Completadas).
List<Widget> buildGroupedTasksSlivers({
  required TaskGroups groups,
  required void Function(NoteItem item) onOpen,
  NotesRepository? repository,
  TextTheme? textTheme,
  bool completedExpanded = false,
  VoidCallback? onToggleCompleted,
}) {
  final hasOther =
      groups.upcoming.isNotEmpty || groups.undated.isNotEmpty;
  final slivers = <Widget>[
    SliverToBoxAdapter(
      child: TaskSectionHeader(
        title: 'Hoy',
        progress: groups.progress,
      ),
    ),
  ];

  if (groups.today.isEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            hasOther
                ? 'Nada para hoy · desliza o abre una tarea para planear tu día'
                : 'Nada para hoy',
            style: textTheme?.bodyMedium?.copyWith(
              color: AppColors.neutral60,
            ),
          ),
        ),
      ),
    );
  } else {
    slivers.add(
      _taskListSliver(
        items: groups.today,
        onOpen: onOpen,
        repository: repository,
      ),
    );
  }

  if (groups.upcoming.isNotEmpty) {
    slivers
      ..add(
        const SliverToBoxAdapter(
          child: TaskSectionHeader(title: 'Próximas'),
        ),
      )
      ..add(
        _taskListSliver(
          items: groups.upcoming,
          onOpen: onOpen,
          repository: repository,
        ),
      );
  }

  if (groups.undated.isNotEmpty) {
    slivers
      ..add(
        const SliverToBoxAdapter(
          child: TaskSectionHeader(title: 'Sin fecha'),
        ),
      )
      ..add(
        _taskListSliver(
          items: groups.undated,
          onOpen: onOpen,
          repository: repository,
        ),
      );
  }

  if (groups.completedEarlier.isNotEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: TaskSectionHeader(
          title: 'Completadas (${groups.completedEarlier.length})',
          trailing: Icon(
            completedExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.neutral60,
          ),
          onTap: onToggleCompleted,
        ),
      ),
    );
    if (completedExpanded) {
      slivers.add(
        _taskListSliver(
          items: groups.completedEarlier,
          onOpen: onOpen,
          repository: repository,
        ),
      );
    }
  }

  slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 88)));
  return slivers;
}

Widget _taskListSliver({
  required List<NoteItem> items,
  required void Function(NoteItem item) onOpen,
  NotesRepository? repository,
}) {
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return SwipeableNoteCard(
          item: item,
          repository: repository,
          onTap: () => onOpen(item),
        );
      },
    ),
  );
}
