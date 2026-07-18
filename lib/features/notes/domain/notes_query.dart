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

  static List<NoteItem> recentFrom(List<NoteItem> items) {
    return items.where((item) => !item.pinned).toList();
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
