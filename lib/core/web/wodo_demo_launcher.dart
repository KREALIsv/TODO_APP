import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/layout/adaptive_breakpoints.dart';
import '../../features/auth/presentation/auth_flow.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/notes/data/notes_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/presentation/privacy_security_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Opens review screens from `?wodo_demo=` (web gallery / QA captures only).
abstract final class WodoDemoLauncher {
  static Future<void> maybeLaunch(
    BuildContext context, {
    required AdaptiveLayout layout,
    required NotesRepository repository,
    required SettingsRepository settings,
    required void Function({required AdaptiveLayout layout}) openSettingsPanel,
  }) async {
    if (!kIsWeb) return;

    final demo = Uri.base.queryParameters['wodo_demo']?.trim().toLowerCase();
    if (demo == null || demo.isEmpty) return;

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;

    // Allow web auth/session restore before opening account-specific screens.
    if (demo == 'settings' ||
        demo == 'privacy-security' ||
        demo == 'approve-pairing' ||
        demo == 'linked-devices' ||
        demo == 'protect-dialog') {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!context.mounted) return;
    }

    switch (demo) {
      case 'home':
        return;
      case 'login':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        );
      case 'register':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const AuthScreen(initialRegistering: true),
          ),
        );
      case 'qr':
        await AuthFlow.openQrLogin(context);
      case 'settings':
        if (layout == AdaptiveLayout.expanded) {
          openSettingsPanel(layout: layout);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              repository: repository,
              settings: settings,
            ),
          ),
        );
      case 'privacy-security':
        await PrivacySecurityScreen.open(context);
      case 'approve-pairing':
        await AuthFlow.openApprovePairing(context);
      case 'linked-devices':
        await AuthFlow.openLinkedDevices(context);
      case 'protect-dialog':
        await PrivacySecurityScreen.open(context);
        if (!context.mounted) return;
        await AuthFlow.enableCloudProtection(context);
    }
  }
}
