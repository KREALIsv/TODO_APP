import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/attachments_repository.dart';
import '../../data/comments_repository.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_attachment.dart';
import '../../domain/note_comment.dart';
import '../attachment_viewer_screen.dart';
import 'attachment_actions.dart';
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
    final timeLabel = formatRelativeTime(comment.createdAt);
    final edited = comment.editedAt != null;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AppSurface.secondary(context),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: AppSurface.cardDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (comment.hasText)
                    Text(comment.body, style: textTheme.bodyMedium),
                  if (comment.hasText && images.isNotEmpty)
                    const SizedBox(height: 10),
                  for (var i = 0; i < images.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _CommentImagePreview(
                      bytes: _attachments.bytesFor(images[i].id),
                      onTap: () => _openViewer(context, images, i),
                      onLongPress: enabled
                          ? () => _showImageMenu(context, images[i])
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                edited ? '$timeLabel · editado' : timeLabel,
                style: secondary,
              ),
              if (enabled) ...[
                Text(' · ', style: secondary),
                _MetaLink(
                  label: 'Editar',
                  onTap: () => _edit(context),
                ),
                Text(' · ', style: secondary),
                _MetaLink(
                  label: 'Eliminar',
                  onTap: () => _delete(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaLink extends StatelessWidget {
  const _MetaLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ThemeTokens.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _CommentImagePreview extends StatelessWidget {
  const _CommentImagePreview({
    required this.bytes,
    required this.onTap,
    this.onLongPress,
  });

  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: ThemeTokens.borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: ThemeTokens.borderRadius,
            border: Border.all(color: AppSurface.border(context)),
          ),
          child: ClipRRect(
            borderRadius: ThemeTokens.borderRadius,
            child: bytes == null
                ? SizedBox(
                    height: 96,
                    child: Center(
                      child: Text(
                        'Imagen no sincronizada',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppSurface.secondary(context),
                            ),
                      ),
                    ),
                  )
                : Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 140,
                  ),
          ),
        ),
      ),
    );
  }
}
