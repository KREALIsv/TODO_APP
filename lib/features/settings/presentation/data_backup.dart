import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/data/tags_repository.dart';
import '../../notes/domain/day_entry.dart';
import '../../notes/domain/note_item.dart';

enum ImportResult { success, cancelled, invalid }

const backupMimeType = 'application/json';
const backupFileExtension = 'json';
const backupFormatVersion = 2;

/// Parsed backup payload (v1 notes-only or v2 full content).
class BackupPayload {
  const BackupPayload({
    required this.version,
    required this.notes,
    this.tags,
    this.dayEntries = const [],
  });

  final int version;
  final List<Map<String, dynamic>> notes;
  final Map<String, dynamic>? tags;
  final List<Map<String, dynamic>> dayEntries;
}

/// Suggested filename for exported backups (`wodo_backup_2026-07-21T12-00-00.json`).
String backupFileName({DateTime? at}) {
  final stamp = (at ?? DateTime.now()).toIso8601String().replaceAll(':', '-');
  return 'wodo_backup_$stamp.$backupFileExtension';
}

String encodeBackup({
  required NotesRepository notes,
  required TagsRepository tags,
  required DayEntriesRepository dayEntries,
}) {
  return jsonEncode({
    'version': backupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'app': 'wodo',
    'notes': notes.exportAllMaps(),
    'tags': tags.exportSnapshot(),
    'dayEntries': dayEntries.exportAllMaps(),
  });
}

/// Legacy alias kept for tests.
String encodeNotesBackup(NotesRepository repo) {
  return encodeBackup(
    notes: repo,
    tags: TagsRepository.instance,
    dayEntries: DayEntriesRepository.instance,
  );
}

List<Map<String, dynamic>>? _parseNoteMaps(List<dynamic> list) {
  final result = <Map<String, dynamic>>[];
  for (final entry in list) {
    if (entry is! Map) return null;
    final map = Map<String, dynamic>.from(entry);
    if (map['id'] == null || map['type'] == null) return null;
    final item = NoteItem.fromMap(map);
    result.add(item.toMap());
  }
  return result;
}

List<Map<String, dynamic>>? _parseDayEntryMaps(List<dynamic>? list) {
  if (list == null) return const [];
  final result = <Map<String, dynamic>>[];
  for (final entry in list) {
    if (entry is! Map) return null;
    final map = Map<String, dynamic>.from(entry);
    if (map['id'] == null ||
        map['noteId'] == null ||
        map['day'] == null ||
        map['via'] == null ||
        map['outcome'] == null) {
      return null;
    }
    final item = DayEntry.fromMap(map);
    result.add(item.toMap());
  }
  return result;
}

Map<String, dynamic>? _parseTagsSnapshot(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(raw);
}

/// Validates and parses a backup JSON payload (v1 or v2).
BackupPayload? parseBackup(String raw) {
  try {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      final notes = _parseNoteMaps(decoded);
      if (notes == null) return null;
      return BackupPayload(version: 1, notes: notes);
    }

    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);

    final notesRaw = map['notes'];
    if (notesRaw is! List) return null;
    final notes = _parseNoteMaps(notesRaw);
    if (notes == null) return null;

    final version = map['version'];
    final intVersion = version is int
        ? version
        : version is num
            ? version.toInt()
            : 1;

    if (intVersion >= 2) {
      final dayEntries = _parseDayEntryMaps(map['dayEntries'] as List?);
      if (dayEntries == null) return null;
      return BackupPayload(
        version: intVersion,
        notes: notes,
        tags: _parseTagsSnapshot(map['tags']),
        dayEntries: dayEntries,
      );
    }

    return BackupPayload(version: 1, notes: notes);
  } catch (_) {
    return null;
  }
}

/// Validates and parses a backup JSON payload into [NoteItem] maps (v1 compat).
List<Map<String, dynamic>>? parseNotesBackup(String raw) {
  return parseBackup(raw)?.notes;
}

Future<void> _shareBackupFile(String payload) async {
  final fileName = backupFileName();
  final bytes = utf8.encode(payload);

  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: backupMimeType,
          ),
        ],
        subject: 'WODO backup',
      ),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(payload);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          name: fileName,
          mimeType: backupMimeType,
        ),
      ],
      subject: 'WODO backup',
    ),
  );
}

Future<void> exportNotesData(
  NotesRepository notes, {
  TagsRepository? tags,
  DayEntriesRepository? dayEntries,
}) async {
  final payload = encodeBackup(
    notes: notes,
    tags: tags ?? TagsRepository.instance,
    dayEntries: dayEntries ?? DayEntriesRepository.instance,
  );
  await _shareBackupFile(payload);
}

Future<void> _ensureTagsFromNotes(
  TagsRepository tags,
  List<Map<String, dynamic>> notes,
) async {
  final names = <String>{};
  for (final map in notes) {
    final raw = map['tags'];
    if (raw is List) {
      for (final tag in raw) {
        final name = tag.toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
  }
  if (names.isNotEmpty) {
    await tags.ensureTags(names);
  }
}

Future<void> applyBackupPayload({
  required BackupPayload payload,
  required NotesRepository notes,
  required TagsRepository tags,
  required DayEntriesRepository dayEntries,
}) async {
  final notesSnapshot = notes.exportAllMaps();
  final tagsSnapshot = tags.exportSnapshot();
  final daySnapshot = dayEntries.exportAllMaps();

  try {
    await notes.replaceAllFromMaps(payload.notes);

    if (payload.version >= 2 && payload.tags != null) {
      await tags.replaceSnapshot(payload.tags!);
    } else {
      await _ensureTagsFromNotes(tags, payload.notes);
    }

    if (payload.version >= 2) {
      await dayEntries.replaceAllFromMaps(payload.dayEntries);
    } else {
      await dayEntries.resetAll();
    }

    await notes.syncAllReminders();
  } catch (_) {
    await notes.replaceAllFromMaps(notesSnapshot);
    await tags.replaceSnapshot(tagsSnapshot);
    await dayEntries.replaceAllFromMaps(daySnapshot);
    rethrow;
  }
}

Future<ImportResult> importNotesData(
  NotesRepository notes, {
  TagsRepository? tags,
  DayEntriesRepository? dayEntries,
}) async {
  final tagsRepo = tags ?? TagsRepository.instance;
  final dayRepo = dayEntries ?? DayEntriesRepository.instance;

  final picked = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (picked == null || picked.files.isEmpty) {
    return ImportResult.cancelled;
  }

  final file = picked.files.first;
  String? raw;
  if (file.bytes != null) {
    raw = utf8.decode(file.bytes!);
  } else if (file.path != null) {
    raw = await File(file.path!).readAsString();
  }
  if (raw == null) return ImportResult.invalid;

  final payload = parseBackup(raw);
  if (payload == null) return ImportResult.invalid;

  try {
    await applyBackupPayload(
      payload: payload,
      notes: notes,
      tags: tagsRepo,
      dayEntries: dayRepo,
    );
    return ImportResult.success;
  } catch (_) {
    return ImportResult.invalid;
  }
}

/// Wipes all local content boxes (notes, tags, day log). Settings are kept.
Future<void> resetAllAppContent({
  NotesRepository? notes,
  TagsRepository? tags,
  DayEntriesRepository? dayEntries,
}) async {
  final notesRepo = notes ?? NotesRepository.instance;
  final tagsRepo = tags ?? TagsRepository.instance;
  final dayRepo = dayEntries ?? DayEntriesRepository.instance;

  await notesRepo.resetAll();
  await tagsRepo.resetToDefaults();
  await dayRepo.resetAll();
}
