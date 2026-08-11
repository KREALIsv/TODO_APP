import 'date_only.dart';
import 'day_entry.dart';
import 'day_view_query.dart';
import 'note_item.dart';
import 'notes_filter.dart';
import 'task_day_query.dart';
import 'task_dates.dart';

class NotesQuery {
  const NotesQuery._();

  static bool useSectionedLayout({
    required NotesFilter filter,
    required String searchQuery,
  }) {
    return filter == NotesFilter.all && searchQuery.trim().isEmpty;
  }

  /// Grouped Hoy / Próximas / Backlog when chip Tareas is active and no search.
  static bool useGroupedTasksLayout({
    required NotesFilter filter,
    required String searchQuery,
  }) {
    return filter == NotesFilter.tasks && searchQuery.trim().isEmpty;
  }

  /// Future-day plan under chip Tareas: that day's tasks + Backlog pool.
  ///
  /// Past days stay day-audit only (no Backlog mixed into the replay).
  static bool usePlanDayWithBacklogLayout({
    required NotesFilter filter,
    required String searchQuery,
    required DateTime day,
    DateTime? now,
  }) {
    if (!useGroupedTasksLayout(filter: filter, searchQuery: searchQuery)) {
      return false;
    }
    return dateOnly(day).isAfter(dateOnly(now ?? DateTime.now()));
  }

  static List<NoteItem> apply({
    required List<NoteItem> items,
    NotesFilter filter = NotesFilter.all,
    String searchQuery = '',
  }) {
    var result = _applyFilter(items, filter);
    result = _applySearch(result, searchQuery);
    return result;
  }

  static List<NoteItem> pinnedFrom(List<NoteItem> items) {
    return items.where((item) => item.pinned).toList();
  }

  /// Unpinned items only (legacy split). Prefer [ofDayFrom] for Home «Del día».
  static List<NoteItem> recentFrom(List<NoteItem> items) {
    return items.where((item) => !item.pinned).toList();
  }

  /// Unpinned items that belong to [day] (local calendar day).
  ///
  /// Notes: created or updated that day.
  /// Tasks: todayAt / dueAt / completedAt on that day, overdue when [day] is
  /// today, captured that day, or any stored [DayEntry] for that day (audit).
  static List<NoteItem> ofDayFrom(
    List<NoteItem> items,
    DateTime day, {
    DateTime? now,
    Map<String, DayEntry>? dayEntriesByNoteId,
  }) {
    final reference = now ?? DateTime.now();
    return items
        .where((item) {
          if (item.pinned) return false;
          if (item.type == NoteType.task && dayEntriesByNoteId != null) {
            final entry = dayEntriesByNoteId[item.id];
            if (DayViewQuery.taskBelongsToDay(
              item,
              day,
              now: reference,
              entry: entry,
            )) {
              return true;
            }
          }
          return belongsToDay(item, day, now: reference);
        })
        .toList();
  }

  static bool belongsToDay(
    NoteItem item,
    DateTime day, {
    DateTime? now,
  }) {
    final key = dateOnly(day);
    final reference = now ?? DateTime.now();

    if (item.type == NoteType.note) {
      return dateOnly(item.createdAt) == key || dateOnly(item.updatedAt) == key;
    }

    return TaskDayQuery.belongsToDay(item, day, now: reference);
  }

  static String emptyMessage({
    required NotesFilter filter,
    required String searchQuery,
    required bool hasAnyItems,
  }) {
    if (!hasAnyItems && filter != NotesFilter.archived) {
      return NotesFilter.all.emptyMessage;
    }
    if (searchQuery.trim().isNotEmpty) {
      return 'No se encontraron notas';
    }
    return filter.emptyMessage;
  }

  static List<NoteItem> _applyFilter(List<NoteItem> items, NotesFilter filter) {
    return switch (filter) {
      NotesFilter.all => items.where((item) => !item.isArchived).toList(),
      NotesFilter.pinned => items
          .where((item) => !item.isArchived && item.pinned)
          .toList(),
      NotesFilter.notes => items
          .where((item) => !item.isArchived && item.type == NoteType.note)
          .toList(),
      NotesFilter.tasks => items
          .where((item) => !item.isArchived && item.type == NoteType.task)
          .toList(),
      NotesFilter.archived =>
        items.where((item) => item.isArchived).toList(),
    };
  }

  static List<NoteItem> _applySearch(List<NoteItem> items, String searchQuery) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query);
    }).toList();
  }
}
