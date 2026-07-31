import 'package:flutter/material.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/domain/auth_errors.dart';
import 'app_alerts.dart';

/// Shows a one-time dialog when [AuthService] ends the session after auth failure.
class SessionExpiryListener extends StatefulWidget {
  const SessionExpiryListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<SessionExpiryListener> createState() => _SessionExpiryListenerState();
}

class _SessionExpiryListenerState extends State<SessionExpiryListener> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final message = AuthService.instance.consumeSessionEndedMessage();
    if (message == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navContext = widget.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      AppAlerts.show(
        navContext,
        title: AuthErrors.sessionExpiredTitle,
        message: message,
        type: AppAlertType.warning,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
