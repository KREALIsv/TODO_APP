enum NoteType { note, task }

class NoteItem {
  const NoteItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.pinned,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  final String id;
  final NoteType type;
  final String title;
  final String body;
  final bool pinned;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  String get preview {
    final source = title.trim().isNotEmpty ? title : body;
    final trimmed = source.trim();
    if (trimmed.isEmpty) return 'Sin contenido';
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 80).trimRight()}…';
  }

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'Sin título';
    final firstLine = trimmed.split('\n').first;
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 60).trimRight()}…';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'pinned': pinned,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory NoteItem.fromMap(Map<dynamic, dynamic> map) {
    return NoteItem(
      id: map['id'] as String,
      type: NoteType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => NoteType.note,
      ),
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      pinned: (map['pinned'] as bool?) ?? false,
      completed: (map['completed'] as bool?) ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      tags: (map['tags'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }

  NoteItem copyWith({
    String? id,
    NoteType? type,
    String? title,
    String? body,
    bool? pinned,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return NoteItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      pinned: pinned ?? this.pinned,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}
