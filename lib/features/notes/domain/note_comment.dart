/// User-authored journal entry on a note or task.
class NoteComment {
  const NoteComment({
    required this.id,
    required this.noteId,
    required this.body,
    required this.createdAt,
    this.editedAt,
  });

  final String id;
  final String noteId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;

  static const int maxBodyLength = 4000;

  bool get hasText => body.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
    };
  }

  factory NoteComment.fromMap(Map<dynamic, dynamic> map) {
    return NoteComment(
      id: map['id'] as String,
      noteId: map['noteId'] as String,
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      editedAt: _parseOptionalDate(map['editedAt']),
    );
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return null;
  }

  NoteComment copyWith({
    String? id,
    String? noteId,
    String? body,
    DateTime? createdAt,
    DateTime? editedAt,
    bool clearEditedAt = false,
  }) {
    return NoteComment(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      editedAt: clearEditedAt ? null : (editedAt ?? this.editedAt),
    );
  }
}
