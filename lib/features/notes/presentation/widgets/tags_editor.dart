import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
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
            _AddTagButton(onPressed: () => _openPicker(context)),
          ],
        ),
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Toca + para buscar o crear etiquetas',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.neutral40,
              ),
            ),
          ),
      ],
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Misma caja tipográfica/padding vertical que TagPill (bodyLarge + 8).
    final lineHeight = (textTheme.bodyLarge?.fontSize ?? 16) * 1.2;

    final height = lineHeight + 16; // padding vertical 8+8
    return Material(
      color: AppColors.neutral00,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(height / 2),
        side: const BorderSide(color: AppColors.neutral20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(height / 2),
        onTap: onPressed,
        child: SizedBox(
          width: height,
          height: height,
          child: const Icon(
            Icons.add,
            size: 20,
            color: AppColors.neutral60,
          ),
        ),
      ),
    );
  }
}
