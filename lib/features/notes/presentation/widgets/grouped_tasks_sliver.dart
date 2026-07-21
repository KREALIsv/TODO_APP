import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_groups.dart';
import 'swipeable_note_card.dart';
import 'task_section_header.dart';

enum GroupedTasksSection { today, upcoming, undated }

class GroupedTasksExpansion {
  const GroupedTasksExpansion({
    this.today = true,
    this.upcoming = true,
    this.undated = true,
  });

  final bool today;
  final bool upcoming;
  final bool undated;

  bool isExpanded(GroupedTasksSection section) => switch (section) {
        GroupedTasksSection.today => today,
        GroupedTasksSection.upcoming => upcoming,
        GroupedTasksSection.undated => undated,
      };

  GroupedTasksExpansion toggle(GroupedTasksSection section) {
    return GroupedTasksExpansion(
      today: section == GroupedTasksSection.today ? !today : today,
      upcoming: section == GroupedTasksSection.upcoming ? !upcoming : upcoming,
      undated: section == GroupedTasksSection.undated ? !undated : undated,
    );
  }
}

/// Builds slivers for grouped tasks (Hoy / Próximas / Sin fecha).
List<Widget> buildGroupedTasksSlivers({
  required TaskGroups groups,
  required void Function(NoteItem item) onOpen,
  NotesRepository? repository,
  TextTheme? textTheme,
  GroupedTasksExpansion expansion = const GroupedTasksExpansion(),
  void Function(GroupedTasksSection section)? onToggleSection,
  String? selectedNoteId,
}) {
  final hasOther =
      groups.upcoming.isNotEmpty || groups.undated.isNotEmpty;
  final sectionCount = 1 +
      (groups.upcoming.isNotEmpty ? 1 : 0) +
      (groups.undated.isNotEmpty ? 1 : 0);
  final collapsible = sectionCount > 1;

  VoidCallback? toggle(GroupedTasksSection section) {
    if (!collapsible || onToggleSection == null) return null;
    return () => onToggleSection(section);
  }

  bool showContent(GroupedTasksSection section) {
    if (!collapsible) return true;
    return expansion.isExpanded(section);
  }

  final slivers = <Widget>[
    SliverToBoxAdapter(
      child: TaskSectionHeader(
        title: 'Hoy',
        progress: groups.progress,
        expanded: collapsible ? expansion.today : null,
        onToggle: toggle(GroupedTasksSection.today),
      ),
    ),
  ];

  if (showContent(GroupedTasksSection.today)) {
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
          selectedNoteId: selectedNoteId,
        ),
      );
    }
  }

  if (groups.upcoming.isNotEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: TaskSectionHeader(
          title: 'Próximas',
          expanded: collapsible ? expansion.upcoming : null,
          onToggle: toggle(GroupedTasksSection.upcoming),
        ),
      ),
    );
    if (showContent(GroupedTasksSection.upcoming)) {
      slivers.add(
        _taskListSliver(
          items: groups.upcoming,
          onOpen: onOpen,
          repository: repository,
          selectedNoteId: selectedNoteId,
        ),
      );
    }
  }

  if (groups.undated.isNotEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: TaskSectionHeader(
          title: 'Sin fecha',
          expanded: collapsible ? expansion.undated : null,
          onToggle: toggle(GroupedTasksSection.undated),
        ),
      ),
    );
    if (showContent(GroupedTasksSection.undated)) {
      slivers.add(
        _taskListSliver(
          items: groups.undated,
          onOpen: onOpen,
          repository: repository,
          selectedNoteId: selectedNoteId,
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
  String? selectedNoteId,
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
          selected: selectedNoteId == item.id,
          onTap: () => onOpen(item),
        );
      },
    ),
  );
}
