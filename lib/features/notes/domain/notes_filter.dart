enum NotesFilter { all, pinned, notes, tasks }

extension NotesFilterLabels on NotesFilter {
  String get label {
    return switch (this) {
      NotesFilter.all => 'Todas',
      NotesFilter.pinned => 'Fijadas',
      NotesFilter.notes => 'Notas',
      NotesFilter.tasks => 'Tareas',
    };
  }

  String get emptyMessage {
    return switch (this) {
      NotesFilter.all => 'Tu primera nota está a un tap',
      NotesFilter.pinned => 'No hay notas fijadas',
      NotesFilter.notes => 'No hay notas',
      NotesFilter.tasks => 'No hay tareas',
    };
  }

  String get listHeader {
    return switch (this) {
      NotesFilter.all => 'Recientes',
      NotesFilter.pinned => 'Fijadas',
      NotesFilter.notes => 'Notas',
      NotesFilter.tasks => 'Tareas',
    };
  }
}
