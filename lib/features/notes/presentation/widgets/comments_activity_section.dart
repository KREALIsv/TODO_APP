import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/attachments_repository.dart';
import '../../data/comments_repository.dart';
import '../../data/day_entries_repository.dart';
import '../../data/note_audit_repository.dart';
import '../../data/notes_repository.dart';
import '../../domain/comment_activity_feed.dart';
import '../../domain/date_only.dart';
import '../../domain/note_audit_event.dart';
import '../../domain/note_item.dart';
import 'attachment_actions.dart';
import 'comment_composer.dart';
import 'comment_tile.dart';
import 'relative_time.dart';
import 'task_day_history_section.dart';

class CommentsActivitySection extends StatelessWidget {
  const CommentsActivitySection({
    super.key,
    required this.noteId,
    required this.enabled,
    required this.noteType,
    this.onDayTap,
    this.coverAttachmentId,
    this.onCoverChanged,
    this.comments,
    this.audits,
    this.dayEntries,
    this.attachments,
    this.notes,
    this.settings,
  });

  final String noteId;
  final bool enabled;
  final NoteType noteType;
  final ValueChanged<DateTime>? onDayTap;
  final String? coverAttachmentId;
  final ValueChanged<String?>? onCoverChanged;
  final CommentsRepository? comments;
  final NoteAuditRepository? audits;
  final DayEntriesRepository? dayEntries;
  final AttachmentsRepository? attachments;
  final NotesRepository? notes;
  final SettingsRepository? settings;

  CommentsRepository get _comments => comments ?? CommentsRepository.instance;
  NoteAuditRepository get _audits => audits ?? NoteAuditRepository.instance;
  DayEntriesRepository get _dayEntries =>
      dayEntries ?? DayEntriesRepository.instance;
  AttachmentsRepository get _attachments =>
      attachments ?? AttachmentsRepository.instance;
  NotesRepository get _notes => notes ?? NotesRepository.instance;
  SettingsRepository get _settings => settings ?? SettingsRepository.instance;

  Future<void> _submit({
    required String body,
    required List<PickedImageBytes> images,
  }) async {
    if (body.isEmpty && images.isEmpty) return;
    final comment = await _comments.add(noteId: noteId, body: body);
    for (final image in images) {
      await _attachments.addImage(
        noteId: noteId,
        bytes: image.bytes,
        fileName: image.fileName,
        mimeType: image.mimeType,
        commentId: comment.id,
      );
    }
    await bumpNoteUpdatedAt(noteId, notes: _notes);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _comments.changes,
        _audits.changes,
        _dayEntries.changes,
        _attachments.listenable(),
        _settings,
        _notes.changes,
      ]),
      builder: (context, _) {
        final hideDetails = _settings.hideCommentAuditDetails;
        final commentRows = _comments.forNote(noteId);
        final dayRows = _dayEntries.entriesForNote(noteId);
        final auditRows = _audits.forNote(noteId);
        final items = buildCommentActivityFeed(
          comments: commentRows,
          dayEntries: dayRows,
          audits: auditRows,
          hideDetails: hideDetails,
        );
        final hasSystem = dayRows.isNotEmpty || auditRows.isNotEmpty;
        final showToggle = hasSystem || hideDetails;
        final textTheme = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'Comentarios',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showToggle)
                  Semantics(
                    button: true,
                    label: hideDetails
                        ? 'Mostrar registros del sistema'
                        : 'Ocultar registros del sistema',
                    child: TextButton(
                      onPressed: () {
                        _settings.setHideCommentAuditDetails(!hideDetails);
                      },
                      child: Text(
                        hideDetails ? 'Mostrar detalles' : 'Ocultar detalles',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            CommentComposer(
              enabled: enabled,
              noteType: noteType,
              onSubmit: _submit,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                hideDetails
                    ? 'No hay comentarios. Muestra los detalles para ver el historial.'
                    : 'Todavía no hay comentarios. Los cambios del sistema aparecerán al guardar.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              )
            else
              for (final item in items)
                switch (item.kind) {
                  CommentFeedKind.comment => CommentTile(
                      comment: item.comment!,
                      comments: _comments,
                      attachments: _attachments,
                      notes: _notes,
                      enabled: enabled,
                      coverAttachmentId: coverAttachmentId,
                      onCoverChanged: onCoverChanged,
                    ),
                  CommentFeedKind.dayEntry => TaskDayHistoryTile(
                      entry: item.dayEntry!,
                      onTap: onDayTap == null
                          ? null
                          : () => onDayTap!(dateOnly(item.dayEntry!.day)),
                    ),
                  CommentFeedKind.audit => _AuditTile(event: item.audit!),
                },
          ],
        );
      },
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.event});

  final NoteAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        event.displaySummary,
        style: textTheme.bodyMedium?.copyWith(
          color: AppSurface.secondary(context),
        ),
      ),
      subtitle: Text(
        formatRelativeTime(event.createdAt),
        style: textTheme.bodySmall?.copyWith(
          color: AppSurface.secondary(context),
        ),
      ),
    );
  }
}
