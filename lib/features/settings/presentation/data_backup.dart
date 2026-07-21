import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';

enum ImportResult { success, cancelled, invalid }

const backupMimeType = 'application/json';
const backupFileExtension = 'json';

/// Suggested filename for exported backups (`wodo_backup_2026-07-21T12-00-00.json`).
String backupFileName({DateTime? at}) {
  final stamp = (at ?? DateTime.now()).toIso8601String().replaceAll(':', '-');
  return 'wodo_backup_$stamp.$backupFileExtension';
}

String encodeNotesBackup(NotesRepository repo) {
  final maps = repo.exportAllMaps();
  return jsonEncode({
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'notes': maps,
  });
}

/// Validates and parses a backup JSON payload into [NoteItem] maps.
List<Map<String, dynamic>>? parseNotesBackup(String raw) {
  try {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final decoded = jsonDecode(trimmed);
    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['notes'] is List) {
      list = decoded['notes'] as List;
    } else {
      return null;
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in list) {
      if (entry is! Map) return null;
      final map = Map<String, dynamic>.from(entry);
      if (map['id'] == null || map['type'] == null) return null;
      // Roundtrip through NoteItem to normalize / reject bad shapes.
      final item = NoteItem.fromMap(map);
      result.add(item.toMap());
    }
    return result;
  } catch (_) {
    return null;
  }
}

Future<void> exportNotesData(NotesRepository repo) async {
  final payload = encodeNotesBackup(repo);
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

Future<ImportResult> importNotesData(NotesRepository repo) async {
  // Accept any file: exports may be saved as .json, .txt, or without extension
  // from the system share sheet. Content is validated below.
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

  final maps = parseNotesBackup(raw);
  if (maps == null) return ImportResult.invalid;

  await repo.replaceAllFromMaps(maps);
  return ImportResult.success;
}
