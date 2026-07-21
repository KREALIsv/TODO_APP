import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../data/attachments_repository.dart';
import '../../data/notes_repository.dart';
import '../../data/tags_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_dates.dart';
import 'relative_time.dart';
import 'tag_pill.dart';
import 'task_date_meta.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.repository,
    this.tagsRepository,
    this.attachmentsRepository,
    this.flat = false,
  });

  final NoteItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final NotesRepository? repository;
  final TagsRepository? tagsRepository;
  final AttachmentsRepository? attachmentsRepository;

  /// When true, skips Card chrome so the parent can clip/shape the row
  /// (e.g. swipe actions inside the same rounded silhouette).
  final bool flat;

  NotesRepository get _repo => repository ?? NotesRepository.instance;
  TagsRepository get _tagsRepo =>
      tagsRepository ?? TagsRepository.instance;
  AttachmentsRepository get _attachments =>
      attachmentsRepository ?? AttachmentsRepository.instance;

  static const double coverHeight = 128;

  Widget _buildBody(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isTask = item.type == NoteType.task;
    final isCompleted = isTask && item.completed;
    final attachmentCount = _attachments.countFor(item.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTask)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: item.completed,
                  onChanged: item.isArchived
                      ? null
                      : (_) => _repo.toggleCompleted(item.id),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 8),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 20,
                color: AppColors.neutral60,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayTitle,
                        style: textTheme.labelLarge?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? AppColors.neutral60
                              : AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.pinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.push_pin,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                if (item.body.trim().isNotEmpty &&
                    item.title.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.body.trim(),
                    style: textTheme.bodySmall?.copyWith(
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...item.tags.take(3).map(
                            (tag) => TagPill(
                              label: tag,
                              colors: _tagsRepo.colorFor(tag),
                              compact: true,
                            ),
                          ),
                      if (item.tags.length > 3)
                        Text(
                          '+${item.tags.length - 3}',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.neutral60,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isTask
                          ? Icons.check_circle_outline
                          : Icons.notes_outlined,
                      size: 12,
                      color: AppColors.neutral40,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTask ? 'Tarea' : 'Nota',
                      style: textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                    Text('· ', style: textTheme.labelSmall),
                    if (item.isArchived)
                      Text(
                        formatRelativeTime(
                          item.archivedAt ?? item.updatedAt,
                        ),
                        style: textTheme.labelSmall,
                      )
                    else if (isTask)
                      Flexible(child: TaskDateMeta(item: item))
                    else
                      Text(
                        formatRelativeTime(item.updatedAt),
                        style: textTheme.labelSmall,
                      ),
                    if (attachmentCount > 0) ...[
                      Text(' · ', style: textTheme.labelSmall),
                      Icon(
                        Icons.attach_file,
                        size: 12,
                        color: AppColors.neutral40,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$attachmentCount',
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCover(BuildContext context, {required bool completed}) {
    final coverId = item.coverAttachmentId;
    if (coverId == null) return null;
    final bytes = _attachments.bytesFor(coverId);
    if (bytes == null) return null;

    return Opacity(
      opacity: completed ? 0.55 : 1,
      child: SizedBox(
        height: coverHeight,
        width: double.infinity,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.type == NoteType.task && item.completed;

    return ValueListenableBuilder<Box<Map>>(
      valueListenable: _attachments.listenable(),
      builder: (context, box, _) {
        final cover = _buildCover(context, completed: isCompleted);
        final content = InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: flat ? BorderRadius.zero : ThemeTokens.borderRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover != null) cover,
              _buildBody(context),
            ],
          ),
        );

        if (flat) {
          return Material(
            color: AppSurface.card(context),
            child: content,
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: content,
        );
      },
    );
  }
}
