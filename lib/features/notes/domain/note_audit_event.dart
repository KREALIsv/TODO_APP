/// System journal kinds that [DayEntry] does not already cover.
enum NoteAuditKind {
  created,
  titleChanged,
  bodyChanged,
  tagsChanged,
  reminderChanged,
  archived,
  restored,
  typeChanged,
  pinnedChanged,
  checklistChanged,
  coverChanged,
}

class NoteAuditEvent {
  const NoteAuditEvent({
    required this.id,
    required this.noteId,
    required this.kind,
    required this.createdAt,
    this.summary,
  });

  final String id;
  final String noteId;
  final NoteAuditKind kind;
  final DateTime createdAt;
  final String? summary;

  String get displaySummary => summary ?? noteAuditSummary(kind);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'kind': kind.name,
      'createdAt': createdAt.toIso8601String(),
      'summary': summary,
    };
  }

  factory NoteAuditEvent.fromMap(Map<dynamic, dynamic> map) {
    return NoteAuditEvent(
      id: map['id'] as String,
      noteId: map['noteId'] as String,
      kind: NoteAuditKind.values.firstWhere(
        (value) => value.name == map['kind'],
        orElse: () => NoteAuditKind.titleChanged,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      summary: map['summary'] as String?,
    );
  }
}

String noteAuditSummary(NoteAuditKind kind) {
  return switch (kind) {
    NoteAuditKind.created => 'Nota creada',
    NoteAuditKind.titleChanged => 'Título actualizado',
    NoteAuditKind.bodyChanged => 'Descripción actualizada',
    NoteAuditKind.tagsChanged => 'Etiquetas actualizadas',
    NoteAuditKind.reminderChanged => 'Recordatorio actualizado',
    NoteAuditKind.archived => 'Archivada',
    NoteAuditKind.restored => 'Restaurada',
    NoteAuditKind.typeChanged => 'Tipo actualizado',
    NoteAuditKind.pinnedChanged => 'Fijado actualizado',
    NoteAuditKind.checklistChanged => 'Checklist actualizado',
    NoteAuditKind.coverChanged => 'Portada actualizada',
  };
}
