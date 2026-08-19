import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/attachments_repository.dart';
import '../../data/comments_repository.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_attachment.dart';
import '../../domain/note_comment.dart';
import '../attachment_viewer_screen.dart';
import 'attachment_actions.dart';
import 'attachment_format.dart';
import 'attachment_thumb_tile.dart';
import 'relative_time.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.comments,
    this.attachments,
    this.notes,
    this.enabled = true,
  });

  final NoteComment comment;
  final CommentsRepository? comments;
  final AttachmentsRepository? attachments;
  final NotesRepository? notes;
  final bool enabled;

  CommentsRepository get _comments => comments ?? CommentsRepository.instance;
  AttachmentsRepository get _attachments =>
      attachments ?? AttachmentsRepository.instance;
  NotesRepository get _notes => notes ?? NotesRepository.instance;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: comment.body);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Escribe un comentario…',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null) return;
    final trimmed = next.trim();
    if (trimmed == comment.body.trim()) return;
    if (trimmed.isEmpty && _attachments.forComment(comment.id).isEmpty) {
      return;
    }
    await _comments.updateBody(comment.id, trimmed);
    await _touchNote();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar',
      message: '¿Eliminar este comentario?',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (!confirmed) return;
    final images = _attachments.forComment(comment.id);
    final note = _notes.getById(comment.noteId);
    final coverWasCommentImage = note != null &&
        images.any((item) => item.id == note.coverAttachmentId);
    await _comments.delete(comment.id);
    if (note == null) return;
    await _notes.update(
      note.copyWith(
        coverAttachmentId: coverWasCommentImage ? null : note.coverAttachmentId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _touchNote() async {
    final note = _notes.getById(comment.noteId);
    if (note == null) return;
    await _notes.update(note.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> _openViewer(
    BuildContext context,
    List<NoteAttachment> images,
    int index,
  ) async {
    final note = _notes.getById(comment.noteId);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentViewerScreen(
          noteId: comment.noteId,
          initialIndex: index,
          coverAttachmentId: note?.coverAttachmentId,
          onCoverChanged: (_) {},
          repository: _attachments,
          items: images,
        ),
      ),
    );
  }

  Future<void> _showImageMenu(
    BuildContext context,
    NoteAttachment item,
  ) async {
    final note = _notes.getById(comment.noteId);
    final isCover = item.id == note?.coverAttachmentId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isCover ? Icons.star_outline : Icons.star),
                title: Text(isCover ? 'Quitar portada' : 'Usar como portada'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  applyCoverAttachmentChange(
                    noteId: comment.noteId,
                    coverAttachmentId: isCover ? null : item.id,
                    onCoverChanged: (_) {},
                    notes: _notes,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Eliminar'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await confirmAndDeleteAttachment(
                    context,
                    item: item,
                    coverAttachmentId: note?.coverAttachmentId,
                    onCoverChanged: (_) {},
                    attachments: _attachments,
                    notes: _notes,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final images = _attachments.forComment(comment.id);
    final note = _notes.getById(comment.noteId);
    final timeLabel = formatRelativeTime(comment.createdAt);
    final edited = comment.editedAt != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comment.hasText)
                      Text(comment.body, style: textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      edited ? '$timeLabel · editado' : timeLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppSurface.secondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                PopupMenuButton<String>(
                  tooltip: 'Más',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _edit(context);
                    } else if (value == 'delete') {
                      _delete(context);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
            ],
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < images.length; i++)
                  _CommentImageThumb(
                    item: images[i],
                    bytes: _attachments.bytesFor(images[i].id),
                    isCover: images[i].id == note?.coverAttachmentId,
                    onTap: () => _openViewer(context, images, i),
                    onLongPress:
                        enabled ? () => _showImageMenu(context, images[i]) : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentImageThumb extends StatelessWidget {
  const _CommentImageThumb({
    required this.item,
    required this.bytes,
    required this.isCover,
    required this.onTap,
    this.onLongPress,
  });

  final NoteAttachment item;
  final Uint8List? bytes;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final thumb = attachmentStripThumbSize(
      imageWidth: item.width,
      imageHeight: item.height,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AttachmentThumbTile(
          bytes: bytes,
          isCover: isCover,
          width: thumb.width,
          height: thumb.height,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
        if (bytes == null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: thumb.width,
            child: Text(
              'Imagen no sincronizada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
