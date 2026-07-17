import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../../../global/widgets/searchable_dropdown.dart';
import 'tag_pill.dart';

/// Editor de etiquetas sobre [SearchableDropdown] compartido.
class TagsEditor extends StatelessWidget {
  const TagsEditor({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.maxTags = 10,
    this.pageSize = 8,
  });

  final List<String> tags;
  final Set<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final int maxTags;
  final int pageSize;

  void _tryAdd(BuildContext context, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    if (tags.length >= maxTags) {
      AppAlerts.show(
        context,
        message: 'Máximo $maxTags etiquetas',
        type: AppAlertType.warning,
      );
      return;
    }

    final exists = tags.any(
      (tag) => tag.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;

    onChanged([...tags, trimmed]);
  }

  void _remove(String tag) {
    onChanged(tags.where((t) => t != tag).toList());
  }

  Set<String> get _availableSuggestions {
    final existing = tags.map((t) => t.toLowerCase()).toSet();
    return suggestions
        .where((s) => !existing.contains(s.toLowerCase()))
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Etiquetas', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (tag) => TagPill(
                      label: tag,
                      onDelete: () => _remove(tag),
                    ),
                  )
                  .toList(),
            ),
          ),
        SearchableDropdown(
          options: _availableSuggestions,
          pageSize: pageSize,
          hintText: 'Buscar o añadir…',
          emptyMessage: 'No hay más categorías',
          noResultsMessage: 'Sin resultados',
          expandTooltip: 'Ver categorías',
          createLabelBuilder: (query) => 'Crear "$query"',
          onSelected: (value) => _tryAdd(context, value),
        ),
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Sin etiquetas',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.neutral40,
              ),
            ),
          ),
      ],
    );
  }
}
