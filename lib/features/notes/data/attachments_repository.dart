import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat, instantiateImageCodec;

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/note_attachment.dart';

/// Local image attachments for notes/tasks.
///
/// Metadata lives in Hive `attachments`; image bytes in `attachment_blobs`
/// so web and native share the same path (and backups can embed bytes).
class AttachmentsRepository {
  AttachmentsRepository._();

  static final AttachmentsRepository instance = AttachmentsRepository._();

  static const String metaBoxName = 'attachments';
  static const String blobBoxName = 'attachment_blobs';
  static const int maxPerNote = 12;
  static const int maxBytesBeforeCompress = 8 * 1024 * 1024;
  static const int maxDecodeEdge = 1920;
  static const _uuid = Uuid();

  late Box<Map> _meta;
  late Box<dynamic> _blobs;

  Future<void> init() async {
    _meta = await Hive.openBox<Map>(metaBoxName);
    _blobs = await Hive.openBox<dynamic>(blobBoxName);
  }

  @visibleForTesting
  Future<void> initWithBoxes({
    required Box<Map> meta,
    required Box<dynamic> blobs,
  }) async {
    _meta = meta;
    _blobs = blobs;
  }

  ValueListenable<Box<Map>> listenable() => _meta.listenable();

  List<NoteAttachment> forNote(String noteId) {
    final items = _meta.values
        .map((raw) => NoteAttachment.fromMap(Map<dynamic, dynamic>.from(raw)))
        .where((a) => a.noteId == noteId)
        .toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  NoteAttachment? getById(String id) {
    final raw = _meta.get(id);
    if (raw == null) return null;
    return NoteAttachment.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  Uint8List? bytesFor(String id) {
    final raw = _blobs.get(id);
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  int countFor(String noteId) => forNote(noteId).length;

  Future<NoteAttachment> addImage({
    required String noteId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    final existing = forNote(noteId);
    if (existing.length >= maxPerNote) {
      throw StateError('Máximo $maxPerNote imágenes por nota');
    }
    if (bytes.lengthInBytes > maxBytesBeforeCompress * 2) {
      throw StateError('La imagen es demasiado grande');
    }

    final compressed = await compressImageBytes(bytes);
    final storedAsPng = _isPng(compressed);
    final id = _uuid.v4();
    final now = DateTime.now();
    final attachment = NoteAttachment(
      id: id,
      noteId: noteId,
      fileName: storedAsPng ? _withPngExtension(fileName) : fileName,
      mimeType: storedAsPng ? 'image/png' : mimeType,
      byteSize: compressed.lengthInBytes,
      createdAt: now,
      sortOrder: existing.isEmpty ? 0 : existing.last.sortOrder + 1,
    );

    await _blobs.put(id, compressed);
    await _meta.put(id, attachment.toMap());
    return attachment;
  }

  Future<void> delete(String id) async {
    await _meta.delete(id);
    await _blobs.delete(id);
  }

  Future<void> deleteForNote(String noteId) async {
    for (final item in forNote(noteId)) {
      await delete(item.id);
    }
  }

  List<Map<String, dynamic>> exportAllMaps() {
    return _meta.values.map((raw) {
      final item = NoteAttachment.fromMap(Map<dynamic, dynamic>.from(raw));
      final bytes = bytesFor(item.id);
      return {
        ...item.toMap(),
        if (bytes != null) 'bytesBase64': base64Encode(bytes),
      };
    }).toList(growable: false);
  }

  Future<void> replaceAllFromMaps(List<Map<String, dynamic>> maps) async {
    await _meta.clear();
    await _blobs.clear();
    for (final map in maps) {
      final copy = Map<String, dynamic>.from(map);
      final b64 = copy.remove('bytesBase64')?.toString();
      final item = NoteAttachment.fromMap(copy);
      await _meta.put(item.id, item.toMap());
      if (b64 != null && b64.isNotEmpty) {
        await _blobs.put(item.id, base64Decode(b64));
      }
    }
  }

  Future<void> resetAll() async {
    await _meta.clear();
    await _blobs.clear();
  }

  @visibleForTesting
  Future<void> clear() => resetAll();
}

bool _isPng(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

String _withPngExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) return '$fileName.png';
  return '${fileName.substring(0, dot)}.png';
}

Future<Uint8List> compressImageBytes(Uint8List input) async {
  try {
    final codec = await instantiateImageCodec(
      input,
      targetWidth: AttachmentsRepository.maxDecodeEdge,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return input;
    final png = byteData.buffer.asUint8List();
    return png.lengthInBytes < input.lengthInBytes * 3 ? png : input;
  } catch (_) {
    return input;
  }
}
