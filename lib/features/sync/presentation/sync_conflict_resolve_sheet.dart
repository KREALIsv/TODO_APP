import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../data/sync_service.dart';
import '../domain/sync_conflict.dart';

typedef SyncConflictResolveAction = Future<void> Function(String conflictCopyId);

/// Opens a bottom sheet to resolve a single sync conflict.
Future<void> showSyncConflictResolveSheet(
  BuildContext context, {
  required SyncConflictPair pair,
  NotesRepository? repository,
  SyncService? syncService,
}) {
  final repo = repository ?? NotesRepository.instance;
  final sync = syncService ?? SyncService.instance;

  Future<void> resolve(SyncConflictResolveAction action) async {
    await action(pair.copy.id);
    if (sync.isAvailable) {
      await sync.syncNow();
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: SyncConflictResolvePanel(
              pair: pair,
              onKeepRemote: pair.hasLinkedCanonical
                  ? () => resolve(repo.resolveSyncConflictKeepRemote)
                  : null,
              onKeepLocal: () => resolve(repo.resolveSyncConflictKeepLocal),
              onKeepBoth: () => resolve(repo.resolveSyncConflictKeepBoth),
            ),
          ),
        ),
      );
    },
  );
}

class SyncConflictResolvePanel extends StatelessWidget {
  const SyncConflictResolvePanel({
    super.key,
    required this.pair,
    required this.onKeepLocal,
    required this.onKeepBoth,
    this.onKeepRemote,
  });

  final SyncConflictPair pair;
  final VoidCallback? onKeepRemote;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepBoth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = pair.copy;
    final canonical = pair.canonical;
    final localLabel = conflictCopyLabel(copy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Resolver conflicto',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          localLabel,
          style: textTheme.bodyMedium?.copyWith(
            color: AppSurface.secondary(context),
          ),
        ),
        const SizedBox(height: 16),
        SyncConflictVersionPreview(
          label: 'Tu versión local',
          item: copy,
        ),
        if (canonical != null) ...[
          const SizedBox(height: 8),
          SyncConflictVersionPreview(
            label: 'Versión en la nube',
            item: canonical,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No se encontró la tarea original enlazada. Podés conservar '
              'esta copia o eliminarla.',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onKeepRemote != null)
              OutlinedButton(
                onPressed: onKeepRemote,
                child: const Text('Usar la nube'),
              ),
            OutlinedButton(
              onPressed: onKeepLocal,
              child: Text(
                canonical != null ? 'Usar mi versión' : 'Conservar copia',
              ),
            ),
            TextButton(
              onPressed: onKeepBoth,
              child: const Text('Mantener ambas'),
            ),
          ],
        ),
      ],
    );
  }
}

class SyncConflictResolveCard extends StatelessWidget {
  const SyncConflictResolveCard({
    super.key,
    required this.pair,
    required this.onKeepRemote,
    required this.onKeepLocal,
    required this.onKeepBoth,
  });

  final SyncConflictPair pair;
  final VoidCallback? onKeepRemote;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepBoth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSurface.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: SyncConflictResolvePanel(
        pair: pair,
        onKeepRemote: onKeepRemote,
        onKeepLocal: onKeepLocal,
        onKeepBoth: onKeepBoth,
      ),
    );
  }
}

class SyncConflictVersionPreview extends StatelessWidget {
  const SyncConflictVersionPreview({
    super.key,
    required this.label,
    required this.item,
  });

  final String label;
  final NoteItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = item.body.trim().isNotEmpty
        ? item.body.trim()
        : item.displayTitle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppSurface.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppSurface.secondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.displayTitle,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (preview != item.displayTitle) ...[
            const SizedBox(height: 4),
            Text(
              preview.length > 120 ? '${preview.substring(0, 120)}…' : preview,
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
          ],
          if (item.type == NoteType.task) ...[
            const SizedBox(height: 6),
            Text(
              item.completed ? 'Completada' : 'Pendiente',
              style: textTheme.labelSmall?.copyWith(
                color: item.completed ? AppColors.primary00 : AppColors.neutral60,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
