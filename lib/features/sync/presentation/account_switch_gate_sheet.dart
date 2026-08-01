import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../sync/data/sync_service.dart';
import '../../sync/domain/account_switch_gate.dart';

Future<void> showAccountSwitchGateSheet(
  BuildContext context, {
  required AccountSwitchPrompt prompt,
  SyncService? syncService,
}) {
  final sync = syncService ?? SyncService.instance;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambio de cuenta',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Iniciaste sesión como ${prompt.toEmail}, pero este dispositivo '
                'todavía tiene datos de ${prompt.fromEmail}.\n\n'
                'Elegí qué hacer antes de sincronizar.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: AppSurface.secondary(sheetContext),
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await sync.resolveAccountSwitchUploadLocal();
                },
                child: const Text('Subir datos locales a esta cuenta'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await sync.resolveAccountSwitchDownloadCloud();
                },
                child: const Text('Usar datos de la nube'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await sync.resolveAccountSwitchKeepLocalPaused();
                },
                child: const Text('Mantener local sin sincronizar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
