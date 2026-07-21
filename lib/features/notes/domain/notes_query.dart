import 'date_only.dart';
import 'note_item.dart';
import 'notes_filter.dart';
import 'task_dates.dart';

class NotesQuery {
  const NotesQuery._();

  static bool useSectionedLayout({
    required NotesFilter filter,
    required String searchQuery,
  }) {
    return filter == NotesFilter.all && searchQuery.trim().isEmpty;
  }

  /// Grouped Hoy / Próximas / Sin fecha when chip Tareas is active and no search.
  static bool useGroupedTasksLayout({
    required NotesFilter filter,
    required String searchQuery,
  }) {
    return filter == NotesFilter.tasks && searchQuery.trim().isEmpty;
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
  /// today, or captured (created) that day so new tasks appear in «Del día».
  static List<NoteItem> ofDayFrom(
    List<NoteItem> items,
    DateTime day, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    return items
        .where(
          (item) => !item.pinned && belongsToDay(item, day, now: reference),
        )
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

    if (dateOnly(item.createdAt) == key) return true;
    if (item.todayAt != null && dateOnly(item.todayAt!) == key) return true;
    if (item.dueAt != null && dateOnly(item.dueAt!) == key) return true;
    if (item.completedAt != null && dateOnly(item.completedAt!) == key) {
      return true;
    }
    if (key == dateOnly(reference) && item.isOverdue(reference)) return true;
    return false;
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
