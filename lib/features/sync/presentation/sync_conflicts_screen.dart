import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../notes/data/notes_repository.dart';
import '../../sync/data/sync_service.dart';
import '../../sync/domain/sync_conflict.dart';
import 'sync_conflict_resolve_sheet.dart';

class SyncConflictsScreen extends StatefulWidget {
  const SyncConflictsScreen({
    super.key,
    this.repository,
    this.syncService,
  });

  final NotesRepository? repository;
  final SyncService? syncService;

  @override
  State<SyncConflictsScreen> createState() => _SyncConflictsScreenState();
}

class _SyncConflictsScreenState extends State<SyncConflictsScreen> {
  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;
  SyncService get _sync => widget.syncService ?? SyncService.instance;

  Future<void> _afterResolution() async {
    if (_sync.isAvailable) {
      await _sync.syncNow();
    }
    if (mounted) setState(() {});
  }

  Future<void> _resolve(
    SyncConflictPair pair,
    Future<void> Function(String conflictCopyId) action,
  ) async {
    await action(pair.copy.id);
    await _afterResolution();
  }

  Future<void> _purgeAll() async {
    final count = _repo.pendingSyncConflictCount;
    if (count == 0) return;

    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar todas las copias',
      message:
          'Se borrarán $count copia${count == 1 ? '' : 's'} de conflicto '
          'y se conservará la versión en la nube de cada tarea.',
      confirmLabel: 'Eliminar copias',
      isDestructive: true,
    );
    if (!confirmed) return;

    await _repo.deleteSyncConflictCopies();
    await _afterResolution();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo.changes,
      builder: (context, _) {
        final conflicts = _repo.getPendingSyncConflicts();
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Conflictos de sincronización'),
            backgroundColor: AppSurface.panelOverlay(context),
            surfaceTintColor: Colors.transparent,
            actions: [
              if (conflicts.isNotEmpty)
                TextButton(
                  onPressed: _purgeAll,
                  child: const Text('Eliminar todas'),
                ),
            ],
          ),
          body: conflicts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: AppColors.neutral40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay conflictos pendientes',
                          style: textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cuando dos dispositivos editen la misma tarea al '
                          'mismo tiempo, podrás elegir qué versión conservar.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppSurface.secondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: conflicts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pair = conflicts[index];
                    return SyncConflictResolveCard(
                      pair: pair,
                      onKeepRemote: pair.hasLinkedCanonical
                          ? () => _resolve(
                                pair,
                                _repo.resolveSyncConflictKeepRemote,
                              )
                          : null,
                      onKeepLocal: () => _resolve(
                        pair,
                        _repo.resolveSyncConflictKeepLocal,
                      ),
                      onKeepBoth: () => _resolve(
                        pair,
                        _repo.resolveSyncConflictKeepBoth,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

void openSyncConflictsScreen(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const SyncConflictsScreen(),
    ),
  );
}
