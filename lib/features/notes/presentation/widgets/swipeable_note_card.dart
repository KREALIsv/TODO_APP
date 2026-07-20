import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_dates.dart';
import 'note_card.dart';
import 'note_card_context_sheet.dart';

class SwipeableNoteCard extends StatelessWidget {
  const SwipeableNoteCard({
    super.key,
    required this.item,
    required this.onTap,
    this.repository,
    this.enableSwipe = true,
  });

  final NoteItem item;
  final VoidCallback onTap;
  final NotesRepository? repository;
  final bool enableSwipe;

  NotesRepository get _repo => repository ?? NotesRepository.instance;

  String get _kind => item.type == NoteType.task ? 'Tarea' : 'Nota';

  Future<void> _undoToast(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
  }) {
    return AppAlerts.showWithAction(
      context,
      message: message,
      type: AppAlertType.success,
      actionLabel: 'Deshacer',
      onAction: onUndo,
    );
  }

  Future<void> _complete(BuildContext context) async {
    final wasCompleted = item.completed;
    await _repo.toggleCompleted(item.id);
    if (!context.mounted) return;
    await _undoToast(
      context,
      message: wasCompleted ? 'Tarea reabierta' : 'Tarea completada',
      onUndo: () => _repo.toggleCompleted(item.id),
    );
  }

  Future<void> _pin(BuildContext context) async {
    final wasPinned = item.pinned;
    await _repo.togglePinned(item.id);
    if (!context.mounted) return;
    await _undoToast(
      context,
      message: wasPinned ? '$_kind desfijada' : '$_kind fijada',
      onUndo: () => _repo.togglePinned(item.id),
    );
  }

  Future<void> _archive(BuildContext context) async {
    await _repo.archive(item.id);
    if (!context.mounted) return;
    await _undoToast(
      context,
      message: '$_kind archivada',
      onUndo: () => _repo.restore(item.id),
    );
  }

  Future<void> _restore(BuildContext context) async {
    await _repo.restore(item.id);
    if (!context.mounted) return;
    await _undoToast(
      context,
      message: '$_kind restaurada',
      onUndo: () => _repo.archive(item.id),
    );
  }

  Future<void> _deleteForever(BuildContext context) async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar',
      message: '¿Eliminar definitivamente? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (!confirmed) return;
    final deleted = item;
    await _repo.delete(item.id);
    if (!context.mounted) return;
    await _undoToast(
      context,
      message: 'Eliminado',
      onUndo: () => _repo.add(deleted),
    );
  }

  Future<void> _duplicate(BuildContext context) async {
    final copy = await _repo.duplicate(item.id);
    if (copy == null || !context.mounted) return;
    await _undoToast(
      context,
      message: '$_kind duplicada',
      onUndo: () => _repo.delete(copy.id),
    );
  }

  Future<void> _showContextMenu(BuildContext context) async {
    final action = await showNoteCardContextSheet(
      context,
      item: item,
      repository: _repo,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case NoteCardContextAction.pin:
        await _pin(context);
      case NoteCardContextAction.duplicate:
        await _duplicate(context);
      case NoteCardContextAction.archive:
        await _archive(context);
      case NoteCardContextAction.restore:
        await _restore(context);
      case NoteCardContextAction.delete:
        await _deleteForever(context);
    }
  }

  ActionPane _pane({
    required double extentRatio,
    required List<Widget> children,
  }) {
    return ActionPane(
      motion: const BehindMotion(),
      extentRatio: extentRatio,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = NoteCard(
      item: item,
      repository: _repo,
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      flat: enableSwipe,
    );

    if (!enableSwipe) {
      return card;
    }

    final isTask = item.type == NoteType.task;
    final isArchived = item.isArchived;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: ThemeTokens.borderRadius,
          side: const BorderSide(color: AppColors.neutral20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Slidable(
          key: ValueKey(item.id),
          startActionPane: isArchived
              ? _pane(
                  extentRatio: 0.28,
                  children: [
                    SlidableAction(
                      onPressed: (_) => _restore(context),
                      backgroundColor: accent,
                      foregroundColor: AppColors.white,
                      icon: Icons.unarchive_outlined,
                      label: 'Restaurar',
                    ),
                  ],
                )
              : isTask
                  ? _pane(
                      extentRatio: 0.28,
                      children: [
                        SlidableAction(
                          onPressed: (_) => _complete(context),
                          backgroundColor: accent,
                          foregroundColor: AppColors.white,
                          icon: item.completed
                              ? Icons.radio_button_unchecked
                              : Icons.check_circle_outline,
                          label: item.completed ? 'Reabrir' : 'Hecho',
                        ),
                      ],
                    )
                  : null,
          endActionPane: isArchived
              ? _pane(
                  extentRatio: 0.28,
                  children: [
                    SlidableAction(
                      onPressed: (_) => _deleteForever(context),
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      icon: Icons.delete_outline,
                      label: 'Eliminar',
                    ),
                  ],
                )
              : _pane(
                  extentRatio: 0.72,
                  children: [
                    SlidableAction(
                      onPressed: (_) => _archive(context),
                      backgroundColor: AppColors.neutral60,
                      foregroundColor: AppColors.white,
                      icon: Icons.archive_outlined,
                      label: 'Archivar',
                    ),
                    SlidableAction(
                      onPressed: (_) => _deleteForever(context),
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      icon: Icons.delete_outline,
                      label: 'Eliminar',
                    ),
                    SlidableAction(
                      onPressed: (_) => _pin(context),
                      backgroundColor: accent,
                      foregroundColor: AppColors.white,
                      icon: item.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin,
                      label: item.pinned ? 'Desfijar' : 'Fijar',
                    ),
                  ],
                ),
          child: card,
        ),
      ),
    );
  }
}
