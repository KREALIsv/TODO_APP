import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import 'tag_pill.dart';

class TagsEditor extends StatefulWidget {
  const TagsEditor({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.maxTags = 10,
  });

  final List<String> tags;
  final Set<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final int maxTags;

  @override
  State<TagsEditor> createState() => _TagsEditorState();
}

class _TagsEditorState extends State<TagsEditor> {
  int _autocompleteKey = 0;

  void _tryAdd(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    if (widget.tags.length >= widget.maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 10 etiquetas')),
      );
      return;
    }

    final exists = widget.tags.any(
      (tag) => tag.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      setState(() => _autocompleteKey++);
      return;
    }

    widget.onChanged([...widget.tags, trimmed]);
    setState(() => _autocompleteKey++);
  }

  void _remove(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  Iterable<String> _optionsFor(String query) {
    final existing = widget.tags.map((t) => t.toLowerCase()).toSet();
    final q = query.trim().toLowerCase();
    final list = widget.suggestions
        .where((s) => !existing.contains(s.toLowerCase()))
        .where((s) => q.isEmpty || s.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Etiquetas', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        if (widget.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.tags
                  .map(
                    (tag) => TagPill(
                      label: tag,
                      onDelete: () => _remove(tag),
                    ),
                  )
                  .toList(),
            ),
          ),
        Autocomplete<String>(
          key: ValueKey(_autocompleteKey),
          optionsBuilder: (textEditingValue) {
            return _optionsFor(textEditingValue.text);
          },
          onSelected: _tryAdd,
          fieldViewBuilder: (
            context,
            textController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextField(
              controller: textController,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                _tryAdd(value);
                onFieldSubmitted();
              },
              decoration: const InputDecoration(
                hintText: 'Añadir tag…',
                prefixIcon: Icon(Icons.sell_outlined),
                isDense: true,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (options.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 160,
                    maxWidth: 280,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.tags.isEmpty)
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
