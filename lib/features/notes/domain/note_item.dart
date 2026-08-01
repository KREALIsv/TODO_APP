import 'checklist_item.dart';

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
    this.reminderMinutesBefore,
    this.coverAttachmentId,
    this.syncConflictOfNoteId,
    this.checklistTitle,
    this.checklistItems = const [],
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

  /// Minutes before [dueAt] to fire a local reminder.
  /// `null` = none; `0` = at due time. See [ReminderOffset].
  final int? reminderMinutesBefore;

  /// Optional cover image from [AttachmentsRepository].
  final String? coverAttachmentId;

  /// When set, this note is a local snapshot created during sync conflict
  /// resolution and points at the canonical note id.
  final String? syncConflictOfNoteId;

  /// Optional checklist section title. `null` = no checklist section.
  final String? checklistTitle;

  /// Subtasks inside [checklistTitle] section.
  final List<ChecklistItem> checklistItems;

  bool get isSyncConflictCopy => syncConflictOfNoteId != null;

  bool get hasChecklist => checklistTitle != null;

  int get checklistCompletedCount =>
      checklistItems.where((item) => item.completed).length;

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
      'reminderMinutesBefore': reminderMinutesBefore,
      'coverAttachmentId': coverAttachmentId,
      if (syncConflictOfNoteId != null)
        'syncConflictOfNoteId': syncConflictOfNoteId,
      if (checklistTitle != null) 'checklistTitle': checklistTitle,
      if (checklistItems.isNotEmpty)
        'checklistItems': checklistItemsToMap(checklistItems),
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
    final rawReminder = map['reminderMinutesBefore'];
    int? reminder;
    if (rawReminder is int) {
      reminder = rawReminder;
    } else if (rawReminder is num) {
      reminder = rawReminder.toInt();
    }

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
      reminderMinutesBefore: reminder,
      coverAttachmentId: map['coverAttachmentId'] as String?,
      syncConflictOfNoteId: map['syncConflictOfNoteId'] as String?,
      checklistTitle: map['checklistTitle'] as String?,
      checklistItems: checklistItemsFromMap(map['checklistItems']),
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
    Object? reminderMinutesBefore = _unset,
    Object? coverAttachmentId = _unset,
    Object? syncConflictOfNoteId = _unset,
    Object? checklistTitle = _unset,
    List<ChecklistItem>? checklistItems,
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
      reminderMinutesBefore: identical(reminderMinutesBefore, _unset)
          ? this.reminderMinutesBefore
          : reminderMinutesBefore as int?,
      coverAttachmentId: identical(coverAttachmentId, _unset)
          ? this.coverAttachmentId
          : coverAttachmentId as String?,
      syncConflictOfNoteId: identical(syncConflictOfNoteId, _unset)
          ? this.syncConflictOfNoteId
          : syncConflictOfNoteId as String?,
      checklistTitle: identical(checklistTitle, _unset)
          ? this.checklistTitle
          : checklistTitle as String?,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }
}
