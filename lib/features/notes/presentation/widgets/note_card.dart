import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import 'relative_time.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.item,
    required this.onTap,
    this.repository,
  });

  final NoteItem item;
  final VoidCallback onTap;
  final NotesRepository? repository;

  NotesRepository get _repo => repository ?? NotesRepository.instance;

  Future<void> _deleteWithUndo(BuildContext context) async {
    final deleted = item;
    await _repo.delete(item.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota eliminada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _repo.add(deleted),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isTask = item.type == NoteType.task;
    final isCompleted = isTask && item.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
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
                      onChanged: (_) => _repo.toggleCompleted(item.id),
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
                    Text(
                      item.displayTitle,
                      style: textTheme.labelLarge?.copyWith(
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted
                            ? AppColors.neutral60
                            : AppColors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        Text(
                          '· ${formatRelativeTime(item.updatedAt)}',
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: item.pinned ? 'Desfijar' : 'Fijar',
                onPressed: () => _repo.togglePinned(item.id),
                icon: Icon(
                  item.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: item.pinned
                      ? AppColors.primary
                      : AppColors.neutral40,
                ),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _deleteWithUndo(context),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.neutral40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
