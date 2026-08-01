import 'package:flutter/material.dart';

import '../../sync/data/sync_service.dart';
import '../../sync/presentation/account_switch_gate_sheet.dart';

/// Prompts the user when they sign in with a different account while local
/// content from the previous account is still on this device.
class AccountSwitchGateListener extends StatefulWidget {
  const AccountSwitchGateListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.syncService,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final SyncService? syncService;

  @override
  State<AccountSwitchGateListener> createState() =>
      _AccountSwitchGateListenerState();
}

class _AccountSwitchGateListenerState extends State<AccountSwitchGateListener> {
  SyncService get _sync => widget.syncService ?? SyncService.instance;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSyncChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSyncChanged());
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (_sync.state != SyncState.accountSwitchRequired) {
      _sheetOpen = false;
      return;
    }
    if (_sheetOpen) return;

    final prompt = _sync.pendingAccountSwitch;
    if (prompt == null) return;

    _sheetOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final navContext = widget.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) {
        _sheetOpen = false;
        return;
      }
      await showAccountSwitchGateSheet(
        navContext,
        prompt: prompt,
        syncService: _sync,
      );
      _sheetOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
