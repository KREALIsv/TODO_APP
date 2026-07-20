import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../global/constants/config.dart';
import '../../../global/themes/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
        backgroundColor: isDark ? const Color(0xFF1C2128) : AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info != null
              ? '${info.version} (${info.buildNumber})'
              : Config.version;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 88,
                    height: 88,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.check_circle_outline,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                Config.title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inbox personal de notas y tareas ligeras.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.neutral60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Versión $version',
                textAlign: TextAlign.center,
                style: textTheme.labelMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}
