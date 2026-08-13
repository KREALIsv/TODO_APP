import 'package:flutter/material.dart';

import '../../../../core/theme/app_surface.dart';
import '../../domain/privacy_security_status.dart';
import 'settings_section.dart';

class PrivacySecurityStatusCard extends StatelessWidget {
  const PrivacySecurityStatusCard({
    super.key,
    required this.status,
  });

  final PrivacySecurityStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tone = status.tone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: tone, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurface.title(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.body,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppSurface.secondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hub row used in Ajustes and Mi cuenta.
class PrivacySecurityHubRow extends StatelessWidget {
  const PrivacySecurityHubRow({
    super.key,
    required this.accent,
    required this.onTap,
  });

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = PrivacySecurityStatus.resolve(accent: accent);
    return SettingsRow(
      icon: Icons.shield_outlined,
      title: 'Privacidad y seguridad',
      subtitle: status.hubSubtitle,
      trailing: status.hubTrailing,
      accent: accent,
      onTap: onTap,
    );
  }
}
