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
            // Con tags: solo ícono (ya hay contexto al lado).
            // Sin tags: chip con texto, sirve de CTA del empty state.
            _AddTagButton(
              onPressed: () => _openPicker(context),
              compact: hasTags,
            ),
          ],
        ),
      ],
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({required this.onPressed, required this.compact});

  final VoidCallback onPressed;

  /// true: solo ícono (hay chips de contexto al lado).
  /// false: pastilla con texto, usada como CTA cuando no hay etiquetas.
  final bool compact;

  /// Mismo radio que [TagPill] en el editor (`compact: false` → 10).
  static final _radius = BorderRadius.circular(10);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final child = Material(
      color: AppColors.neutral00,
      shape: RoundedRectangleBorder(
        borderRadius: _radius,
        side: const BorderSide(color: AppColors.neutral20),
      ),
      child: InkWell(
        borderRadius: _radius,
        onTap: onPressed,
        child: Padding(
          // Mismo padding que TagPill (no compact, sin botón delete).
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: AppColors.neutral60),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  'Añadir etiqueta',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.neutral60,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (compact) {
      return Tooltip(message: 'Añadir etiqueta', child: child);
    }
    return child;
  }
}
