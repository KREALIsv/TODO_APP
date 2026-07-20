import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';

enum ImportResult { success, cancelled, invalid }

/// Validates and parses a backup JSON payload into [NoteItem] maps.
List<Map<String, dynamic>>? parseNotesBackup(String raw) {
  try {
    final decoded = jsonDecode(raw);
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
  final maps = repo.exportAllMaps();
  final payload = jsonEncode({
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'notes': maps,
  });

  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(text: payload, subject: 'Todos backup'),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File('${dir.path}/todos_backup_$stamp.json');
  await file.writeAsString(payload);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Todos backup',
    ),
  );
}

Future<ImportResult> importNotesData(NotesRepository repo) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
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
