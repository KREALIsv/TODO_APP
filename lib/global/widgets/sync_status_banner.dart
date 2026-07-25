import 'package:flutter/material.dart';

import '../../features/sync/data/sync_service.dart';

/// Small, non-blocking banner while cloud sync runs in the background.
///
/// Local Hive data stays visible underneath; this only signals refresh activity.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.child,
    this.syncService,
  });

  final Widget child;
  final SyncService? syncService;

  SyncService get _sync => syncService ?? SyncService.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sync,
      builder: (context, _) {
        final syncing = _sync.state == SyncState.syncing;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: syncing
                    ? Material(
                        key: const ValueKey('sync-banner'),
                        elevation: 2,
                        color:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Actualizando datos…',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('sync-banner-off'),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
