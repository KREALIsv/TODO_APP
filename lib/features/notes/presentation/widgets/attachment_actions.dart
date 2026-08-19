import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../global/widgets/app_alerts.dart';
import '../../data/attachments_repository.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_attachment.dart';

class PickedImageBytes {
  const PickedImageBytes({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

Future<PickedImageBytes?> pickImageBytes({
  required ImageSource source,
  ImagePicker? picker,
}) async {
  final file = await (picker ?? ImagePicker()).pickImage(
    source: source,
    maxWidth: AttachmentsRepository.maxDecodeEdge.toDouble(),
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedImageBytes(
    bytes: await file.readAsBytes(),
    fileName: file.name,
    mimeType: file.mimeType ?? 'image/jpeg',
  );
}

Future<NoteAttachment?> pickAndStoreImage({
  required String noteId,
  required ImageSource source,
  String? commentId,
  ImagePicker? picker,
  AttachmentsRepository? attachments,
}) async {
  final picked = await pickImageBytes(source: source, picker: picker);
  if (picked == null) return null;
  return (attachments ?? AttachmentsRepository.instance).addImage(
    noteId: noteId,
    bytes: picked.bytes,
    fileName: picked.fileName,
    mimeType: picked.mimeType,
    commentId: commentId,
  );
}

Future<void> showAddImageSourceSheet(
  BuildContext context, {
  required ValueChanged<ImageSource> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                onSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                onSelected(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Updates draft cover via [onCoverChanged] and, when the note already exists,
/// persists [coverAttachmentId] immediately (same idea as delete clearing cover).
Future<void> applyCoverAttachmentChange({
  required String noteId,
  required String? coverAttachmentId,
  required ValueChanged<String?> onCoverChanged,
  NotesRepository? notes,
}) async {
  onCoverChanged(coverAttachmentId);
  final notesRepo = notes ?? NotesRepository.instance;
  final note = notesRepo.getById(noteId);
  if (note == null || note.coverAttachmentId == coverAttachmentId) return;
  await notesRepo.update(
    note.copyWith(
      coverAttachmentId: coverAttachmentId,
      updatedAt: DateTime.now(),
    ),
  );
}

/// Confirms and deletes an attachment. Per PRD, clearing a cover sets
/// [coverAttachmentId] to null (no auto-promote). Also syncs a persisted
/// note when its stored cover pointed at the deleted file.
Future<bool> confirmAndDeleteAttachment(
  BuildContext context, {
  required NoteAttachment item,
  required String? coverAttachmentId,
  required ValueChanged<String?> onCoverChanged,
  AttachmentsRepository? attachments,
  NotesRepository? notes,
}) async {
  final confirmed = await AppAlerts.confirm(
    context,
    title: 'Eliminar imagen',
    message: '¿Eliminar esta imagen?',
    confirmLabel: 'Eliminar',
    isDestructive: true,
  );
  if (!confirmed) return false;

  final attachmentsRepo = attachments ?? AttachmentsRepository.instance;
  final notesRepo = notes ?? NotesRepository.instance;
  final wasCover = item.id == coverAttachmentId;

  await attachmentsRepo.delete(item.id);

  if (wasCover) {
    onCoverChanged(null);
  }

  final note = notesRepo.getById(item.noteId);
  if (note != null && note.coverAttachmentId == item.id) {
    await notesRepo.update(
      note.copyWith(
        coverAttachmentId: null,
        updatedAt: DateTime.now(),
      ),
    );
  }

  return true;
}
