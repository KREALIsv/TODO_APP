import 'date_only.dart';

/// How a note became part of a day's log.
enum DayVia { todaySwitch, due, migratedIn, scheduledIn, manual }

/// Closing state of a day log row (Bullet Journal–style outcomes).
enum DayOutcome {
  open,
  completed,
  migrated,
  scheduled,
  cancelled,
  backlogged,
}

/// Sentinel so [DayEntry.copyWith] can explicitly set nullable fields to null.
const Object _unset = Object();

/// Append-friendly day log row keyed logically by (noteId, day).
class DayEntry {
  const DayEntry({
    required this.id,
    required this.noteId,
    required this.day,
    required this.via,
    required this.outcome,
    required this.createdAt,
    this.targetDay,
    this.outcomeAt,
  });

  final String id;
  final String noteId;

  /// Local calendar day (time zeroed).
  final DateTime day;
  final DayVia via;
  final DayOutcome outcome;

  /// Destination day when [outcome] is migrated/scheduled.
  final DateTime? targetDay;

  /// When the outcome closed; null while [outcome] is [DayOutcome.open].
  final DateTime? outcomeAt;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'day': dateOnly(day).toIso8601String(),
      'via': via.name,
      'outcome': outcome.name,
      'targetDay': targetDay == null
          ? null
          : dateOnly(targetDay!).toIso8601String(),
      'outcomeAt': outcomeAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return null;
  }

  static DateTime _parseDay(dynamic value) {
    final parsed = DateTime.parse(value as String);
    return dateOnly(parsed);
  }

  factory DayEntry.fromMap(Map<dynamic, dynamic> map) {
    final rawTarget = _parseOptionalDate(map['targetDay']);
    return DayEntry(
      id: map['id'] as String,
      noteId: map['noteId'] as String,
      day: _parseDay(map['day']),
      via: DayVia.values.firstWhere(
        (value) => value.name == map['via'],
        orElse: () => DayVia.manual,
      ),
      outcome: DayOutcome.values.firstWhere(
        (value) => value.name == map['outcome'],
        orElse: () => DayOutcome.open,
      ),
      targetDay: rawTarget == null ? null : dateOnly(rawTarget),
      outcomeAt: _parseOptionalDate(map['outcomeAt']),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  DayEntry copyWith({
    String? id,
    String? noteId,
    DateTime? day,
    DayVia? via,
    DayOutcome? outcome,
    Object? targetDay = _unset,
    Object? outcomeAt = _unset,
    DateTime? createdAt,
  }) {
    return DayEntry(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      day: day != null ? dateOnly(day) : this.day,
      via: via ?? this.via,
      outcome: outcome ?? this.outcome,
      targetDay: identical(targetDay, _unset)
          ? this.targetDay
          : (targetDay == null ? null : dateOnly(targetDay as DateTime)),
      outcomeAt: identical(outcomeAt, _unset)
          ? this.outcomeAt
          : outcomeAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
