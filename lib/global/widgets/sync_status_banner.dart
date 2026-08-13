import 'package:flutter/material.dart';

import '../../features/notes/data/notes_repository.dart';
import '../../features/sync/data/sync_service.dart';
import '../../features/sync/presentation/account_switch_gate_sheet.dart';
import '../../features/sync/presentation/sync_conflicts_screen.dart';

/// Non-blocking sync signals layered above app content.
///
/// The syncing chip is a dismissible floating toast so it does not cover the
/// detail/header chrome. Conflict / account-switch prompts stay tappable.
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({
    super.key,
    required this.child,
    this.syncService,
    this.notesRepository,
  });

  final Widget child;
  final SyncService? syncService;
  final NotesRepository? notesRepository;

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  SyncService get _sync => widget.syncService ?? SyncService.instance;
  NotesRepository get _notes =>
      widget.notesRepository ?? NotesRepository.instance;

  /// Hides the current syncing toast until sync leaves [SyncState.syncing].
  bool _syncChipDismissed = false;
  SyncState? _lastSyncState;

  void _onSyncTick() {
    final state = _sync.state;
    if (_lastSyncState == SyncState.syncing && state != SyncState.syncing) {
      _syncChipDismissed = false;
    }
    _lastSyncState = state;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sync, _notes.changes]),
      builder: (context, _) {
        _onSyncTick();
        final syncing = _sync.state == SyncState.syncing;
        final accountSwitchRequired =
            _sync.state == SyncState.accountSwitchRequired;
        final conflictCount = _notes.pendingSyncConflictCount;
        final showConflictBanner =
            !syncing && !accountSwitchRequired && conflictCount > 0;
        final showSyncChip = syncing && !_syncChipDismissed;

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (showSyncChip)
              Positioned(
                // Inset + centered so back/share chrome on detail screens
                // stays tappable beside the floating toast.
                top: MediaQuery.paddingOf(context).top + 8,
                left: 56,
                right: 56,
                child: _SyncingChip(
                  onDismiss: () => setState(() => _syncChipDismissed = true),
                ),
              ),
            if (accountSwitchRequired || showConflictBanner)
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
                      child: accountSwitchRequired
                          ? _AccountSwitchBanner(
                              key: const ValueKey('account-switch-banner'),
                              onTap: () {
                                final prompt = _sync.pendingAccountSwitch;
                                if (prompt == null) return;
                                showAccountSwitchGateSheet(
                                  context,
                                  prompt: prompt,
                                  syncService: _sync,
                                );
                              },
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('account-switch-banner-off'),
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

class _SyncingChip extends StatelessWidget {
  const _SyncingChip({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Actualizando datos…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSwitchBanner extends StatelessWidget {
  const _AccountSwitchBanner({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: colorScheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.switch_account_outlined,
                  size: 18,
                  color: colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cambio de cuenta · Elegí qué hacer con tus datos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onTertiaryContainer,
                ),
              ],
            ),
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
