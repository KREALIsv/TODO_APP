import 'package:flutter/material.dart';

import '../../../core/theme/app_surface.dart';
import '../../../global/themes/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../notes/domain/tag_colors.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/sync_service.dart';
import 'profile_panel.dart';

/// Account identity and primary auth actions at the top of Perfil.
class ProfileAccountSection extends StatelessWidget {
  const ProfileAccountSection({
    super.key,
    this.density = ProfilePanelDensity.fullScreen,
  });

  final ProfilePanelDensity density;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.instance,
        SyncService.instance,
        DeviceIdentity.instance,
      ]),
      builder: (context, _) {
        final auth = AuthService.instance;
        final textTheme = Theme.of(context).textTheme;
        final isSidebar = density == ProfilePanelDensity.sidebar;
        final status = AuthFlow.accountStatusLabel(
          isConfigured: auth.isConfigured,
          isAuthenticated: auth.isAuthenticated,
          syncEnabled: DeviceIdentity.instance.syncEnabled,
          syncState: SyncService.instance.state,
        );

        if (!auth.isAuthenticated) {
          return _LoggedOutCard(
            textTheme: textTheme,
            status: status,
            compact: isSidebar,
            canSignIn: auth.isConfigured,
            onSignIn: () => AuthFlow.openLogin(
              context,
              contextTitle: 'Tu cuenta WODO',
              contextMessage:
                  'Inicia sesión para sincronizar notas y tareas entre tus dispositivos. '
                  'Sin cuenta, todo sigue guardándose aquí en local.',
            ),
          );
        }

        return _LoggedInCard(
          textTheme: textTheme,
          email: auth.userEmail ?? 'Cuenta WODO',
          initials: auth.userInitials,
          status: status,
          deviceLabel: DeviceIdentity.instance.platformLabel,
          compact: isSidebar,
          syncEnabled: DeviceIdentity.instance.syncEnabled,
          syncing: SyncService.instance.state == SyncState.syncing,
          onOpenAccount: () => AuthFlow.openAccount(context),
          onSyncNow: DeviceIdentity.instance.syncEnabled
              ? () => AuthFlow.syncNow(context)
              : null,
          onLogout: () => AuthFlow.logout(context),
        );
      },
    );
  }
}

class _LoggedOutCard extends StatelessWidget {
  const _LoggedOutCard({
    required this.textTheme,
    required this.status,
    required this.compact,
    required this.canSignIn,
    required this.onSignIn,
  });

  final TextTheme textTheme;
  final String status;
  final bool compact;
  final bool canSignIn;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: AppSurface.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountAvatar(
                initials: null,
                compact: compact,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sin cuenta',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppSurface.title(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppSurface.secondary(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          if (canSignIn)
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Iniciar sesión'),
            )
          else
            Text(
              'La sincronización entre dispositivos estará disponible pronto.',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoggedInCard extends StatelessWidget {
  const _LoggedInCard({
    required this.textTheme,
    required this.email,
    required this.initials,
    required this.status,
    required this.deviceLabel,
    required this.compact,
    required this.syncEnabled,
    required this.syncing,
    required this.onOpenAccount,
    required this.onSyncNow,
    required this.onLogout,
  });

  final TextTheme textTheme;
  final String email;
  final String initials;
  final String status;
  final String deviceLabel;
  final bool compact;
  final bool syncEnabled;
  final bool syncing;
  final VoidCallback onOpenAccount;
  final VoidCallback? onSyncNow;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSurface.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenAccount,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 16,
                compact ? 14 : 16,
                compact ? 14 : 16,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountAvatar(
                    initials: initials,
                    compact: compact,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppSurface.title(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusChip(
                              label: 'Conectada',
                              color: AppColors.primary,
                            ),
                            _StatusChip(
                              label: deviceLabel,
                              color: AppColors.neutral60,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          status,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppSurface.secondary(context),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Ver datos de cuenta',
                              style: textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: syncing ? null : onSyncNow,
                    icon: syncing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(syncing ? 'Sincronizando…' : 'Sincronizar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Salir'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!syncEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Activa la sincronización en Ajustes → Sincronizar aquí.',
                style: textTheme.labelSmall?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.initials,
    required this.compact,
  });

  final String? initials;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 52.0;
    final loggedIn = initials != null && initials!.isNotEmpty;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor:
          loggedIn ? TagColors.brandPink : AppColors.neutral20,
      child: loggedIn
          ? Text(
              initials!,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 15 : 17,
              ),
            )
          : Icon(
              Icons.person_outline_rounded,
              color: AppColors.neutral60,
              size: compact ? 22 : 26,
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
