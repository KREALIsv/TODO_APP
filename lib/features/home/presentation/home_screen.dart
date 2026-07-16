import 'package:flutter/material.dart';

import '../../../global/constants/constants.dart';
import '../../../global/themes/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(Config.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Headline', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Body — estructura base lista para el MVP.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text('Label', style: textTheme.labelMedium),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _ColorSwatch(label: 'Primary', color: AppColors.primary),
                _ColorSwatch(label: 'Secondary', color: AppColors.secondary),
                _ColorSwatch(label: 'Tertiary', color: AppColors.tertiary),
                _ColorSwatch(label: 'Neutral', color: AppColors.neutral),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral20),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
