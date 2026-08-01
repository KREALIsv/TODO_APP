import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/outlined_add_chip.dart';
import '../../domain/checklist_item.dart';

typedef ChecklistChanged = void Function({
  required String? title,
  required List<ChecklistItem> items,
});

/// Checklist section for tasks: action button to create, then subtask rows.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.title,
    required this.items,
    required this.onChanged,
    this.showAddButton = true,
  });

  final String? title;
  final List<ChecklistItem> items;
  final ChecklistChanged onChanged;
  final bool showAddButton;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  static const _uuid = Uuid();

  bool get _hasChecklist => widget.title != null;

  Future<void> _showAddChecklistDialog() async {
    final controller = TextEditingController(text: 'Checklist');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Añadir checklist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
            ),
            onSubmitted: (_) =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || result == null) return;
    final title = result.isEmpty ? 'Checklist' : result;
    widget.onChanged(title: title, items: widget.items);
  }

  void _toggleItem(String id) {
    widget.onChanged(
      title: widget.title,
      items: widget.items
          .map(
            (item) => item.id == id
                ? item.copyWith(completed: !item.completed)
                : item,
          )
          .toList(),
    );
  }

  void _updateItemTitle(String id, String title) {
    widget.onChanged(
      title: widget.title,
      items: widget.items
          .map((item) => item.id == id ? item.copyWith(title: title) : item)
          .toList(),
    );
  }

  void _removeItem(String id) {
    widget.onChanged(
      title: widget.title,
      items: widget.items.where((item) => item.id != id).toList(),
    );
  }

  void _addItem() {
    final nextOrder = widget.items.isEmpty
        ? 0
        : widget.items.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) +
            1;
    widget.onChanged(
      title: widget.title,
      items: [
        ...widget.items,
        ChecklistItem(
          id: _uuid.v4(),
          title: '',
          sortOrder: nextOrder,
        ),
      ],
    );
  }

  Future<void> _deleteChecklist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar checklist'),
        content: const Text(
          '¿Eliminar la lista de comprobación y todos sus elementos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onChanged(title: null, items: const []);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!_hasChecklist) {
      if (!widget.showAddButton) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: 'Crear lista de comprobación',
          child: _ActionChip(
            icon: Icons.check_box_outlined,
            label: 'Checklist',
            onPressed: _showAddChecklistDialog,
          ),
        ),
      );
    }

    final total = widget.items.length;
    final done = widget.items.where((item) => item.completed).length;
    final progress = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_box_outlined,
              size: 20,
              color: AppColors.neutral60,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title!,
                style: textTheme.labelLarge,
              ),
            ),
            IconButton(
              tooltip: 'Eliminar checklist',
              onPressed: _deleteChecklist,
              icon: const Icon(Icons.more_horiz, size: 20),
            ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$done/$total',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.neutral60,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.neutral20,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        ...widget.items.map((item) => _ChecklistItemRow(
              item: item,
              onToggle: () => _toggleItem(item.id),
              onTitleChanged: (title) => _updateItemTitle(item.id, title),
              onDelete: () => _removeItem(item.id),
            )),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedAddChip(
            label: 'Añadir elemento',
            onPressed: _addItem,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.neutral00,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.neutral60),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.neutral60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistItemRow extends StatefulWidget {
  const _ChecklistItemRow({
    required this.item,
    required this.onToggle,
    required this.onTitleChanged,
    required this.onDelete,
  });

  final ChecklistItem item;
  final VoidCallback onToggle;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onDelete;

  @override
  State<_ChecklistItemRow> createState() => _ChecklistItemRowState();
}

class _ChecklistItemRowState extends State<_ChecklistItemRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    _focusNode = FocusNode();
    if (widget.item.title.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ChecklistItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.title != widget.item.title &&
        _controller.text != widget.item.title) {
      _controller.text = widget.item.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final completed = widget.item.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: completed,
              onChanged: (_) => widget.onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              style: textTheme.bodyMedium?.copyWith(
                decoration:
                    completed ? TextDecoration.lineThrough : null,
                color: completed ? AppColors.neutral60 : AppColors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Nuevo elemento',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: widget.onTitleChanged,
              onSubmitted: (_) => _focusNode.unfocus(),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar elemento',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
