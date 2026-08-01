import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../../sync/data/sync_service.dart';
import '../../sync/domain/sync_conflict.dart';

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
                    return _ConflictCard(
                      pair: conflicts[index],
                      onKeepRemote: () => _resolve(
                        conflicts[index],
                        _repo.resolveSyncConflictKeepRemote,
                      ),
                      onKeepLocal: () => _resolve(
                        conflicts[index],
                        _repo.resolveSyncConflictKeepLocal,
                      ),
                      onKeepBoth: () => _resolve(
                        conflicts[index],
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

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.pair,
    required this.onKeepRemote,
    required this.onKeepLocal,
    required this.onKeepBoth,
  });

  final SyncConflictPair pair;
  final VoidCallback onKeepRemote;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepBoth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = pair.copy;
    final canonical = pair.canonical;
    final localLabel = conflictCopyLabel(copy);

    return Container(
      decoration: AppSurface.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync_problem_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localLabel,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VersionPreview(
            label: 'Tu versión local',
            item: copy,
          ),
          if (canonical != null) ...[
            const SizedBox(height: 8),
            _VersionPreview(
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
              if (canonical != null)
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
      ),
    );
  }
}

class _VersionPreview extends StatelessWidget {
  const _VersionPreview({
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

void openSyncConflictsScreen(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const SyncConflictsScreen(),
    ),
  );
}
