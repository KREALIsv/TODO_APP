import 'package:flutter/material.dart';

import '../../../../global/widgets/outlined_add_chip.dart';
import '../../data/tags_repository.dart';
import 'tag_pill.dart';
import 'tags_picker_sheet.dart';

/// Editor de etiquetas: pastillas seleccionadas + botón (+) que abre el modal.
class TagsEditor extends StatelessWidget {
  const TagsEditor({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.tagsRepository,
    this.maxTags = 10,
  });

  final List<String> tags;
  final Set<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final TagsRepository? tagsRepository;
  final int maxTags;

  TagsRepository get _repo => tagsRepository ?? TagsRepository.instance;

  Future<void> _openPicker(BuildContext context) {
    return showTagsPickerSheet(
      context,
      selectedTags: tags,
      catalog: suggestions,
      tagsRepository: _repo,
      maxTags: maxTags,
      onChanged: onChanged,
    );
  }

  void _remove(String tag) {
    onChanged(tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasTags = tags.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Etiquetas', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...tags.map(
              (tag) => TagPill(
                label: tag,
                colors: _repo.colorFor(tag),
                onDelete: () => _remove(tag),
              ),
            ),
            // Con tags: solo ícono. Sin tags: chip CTA (misma pastilla que adjuntos).
            OutlinedAddChip(
              label: 'Añadir etiqueta',
              compact: hasTags,
              onPressed: () => _openPicker(context),
            ),
          ],
        ),
      ],
    );
  }
}
