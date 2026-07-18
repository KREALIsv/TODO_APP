enum NoteType { note, task }

/// Sentinel so [NoteItem.copyWith] can explicitly set nullable fields to null.
const Object _unset = Object();

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
    this.dueAt,
    this.dueHasTime = false,
    this.todayAt,
    this.completedAt,
    this.archivedAt,
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
  final DateTime? dueAt;
  final bool dueHasTime;
  final DateTime? todayAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;

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
      'dueAt': dueAt?.toIso8601String(),
      'dueHasTime': dueHasTime,
      'todayAt': todayAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return null;
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
      dueAt: _parseOptionalDate(map['dueAt']),
      dueHasTime: (map['dueHasTime'] as bool?) ?? false,
      todayAt: _parseOptionalDate(map['todayAt']),
      completedAt: _parseOptionalDate(map['completedAt']),
      archivedAt: _parseOptionalDate(map['archivedAt']),
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
    Object? dueAt = _unset,
    bool? dueHasTime,
    Object? todayAt = _unset,
    Object? completedAt = _unset,
    Object? archivedAt = _unset,
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
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
      dueHasTime: dueHasTime ?? this.dueHasTime,
      todayAt: identical(todayAt, _unset) ? this.todayAt : todayAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
    );
  }
}
