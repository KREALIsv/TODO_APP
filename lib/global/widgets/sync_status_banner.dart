import 'package:flutter/material.dart';

import '../../features/notes/data/notes_repository.dart';
import '../../features/sync/data/sync_service.dart';
import '../../features/sync/presentation/sync_conflicts_screen.dart';

/// Small, non-blocking banners for cloud sync activity and pending conflicts.
///
/// Local Hive data stays visible underneath; this only signals background work.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.child,
    this.syncService,
    this.notesRepository,
  });

  final Widget child;
  final SyncService? syncService;
  final NotesRepository? notesRepository;

  SyncService get _sync => syncService ?? SyncService.instance;
  NotesRepository get _notes => notesRepository ?? NotesRepository.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sync, _notes.changes]),
      builder: (context, _) {
        final syncing = _sync.state == SyncState.syncing;
        final conflictCount = _notes.pendingSyncConflictCount;
        final showConflictBanner = !syncing && conflictCount > 0;

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: syncing
                        ? _SyncingBanner(key: const ValueKey('sync-banner'))
                        : const SizedBox.shrink(
                            key: ValueKey('sync-banner-off'),
                          ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showConflictBanner
                        ? _ConflictBanner(
                            key: const ValueKey('conflict-banner'),
                            count: conflictCount,
                            onTap: () => openSyncConflictsScreen(context),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('conflict-banner-off'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SyncingBanner extends StatelessWidget {
  const _SyncingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Actualizando datos…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.sync_problem_rounded,
                  size: 18,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 conflicto de sincronización · Revisar'
                        : '$count conflictos de sincronización · Revisar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
