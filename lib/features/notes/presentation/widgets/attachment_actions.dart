import 'package:flutter/material.dart';

import '../../../../global/widgets/app_alerts.dart';
import '../../data/attachments_repository.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_attachment.dart';

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
