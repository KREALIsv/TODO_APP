import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/tokens.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../data/sync_service.dart';
import '../domain/sync_conflict.dart';
import 'sync_conflict_resolve_sheet.dart';

/// Compact list row for a pending sync conflict with a one-tap resolve action.
class SyncConflictListCard extends StatelessWidget {
  const SyncConflictListCard({
    super.key,
    required this.pair,
    this.repository,
    this.syncService,
  });

  final SyncConflictPair pair;
  final NotesRepository? repository;
  final SyncService? syncService;

  NotesRepository get _repo => repository ?? NotesRepository.instance;

  Future<void> _openResolve(BuildContext context) {
    return showSyncConflictResolveSheet(
      context,
      pair: pair,
      repository: _repo,
      syncService: syncService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final copy = pair.copy;
    final title = conflictCopyLabel(copy);
    final cloudTitle = pair.canonical?.displayTitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: ThemeTokens.borderRadius,
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openResolve(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sync_problem_rounded,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Conflicto de sincronización',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (cloudTitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'En la nube: $cloudTitle',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppSurface.secondary(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () => _openResolve(context),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Resolver'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

SyncConflictPair? syncConflictPairFor(
  NoteItem item,
  NotesRepository repository,
) {
  if (!isSyncConflictCopy(item)) return null;
  return SyncConflictPair(
    copy: item,
    canonical: item.syncConflictOfNoteId == null
        ? null
        : repository.getById(item.syncConflictOfNoteId!),
  );
}
