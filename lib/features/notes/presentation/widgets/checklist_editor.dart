import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/outlined_add_chip.dart';
import '../../domain/checklist_item.dart';

typedef ChecklistChanged = void Function({
  required String? title,
  required List<ChecklistItem> items,
});

const _borderlessFieldDecoration = InputDecoration(
  isDense: true,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  contentPadding: EdgeInsets.symmetric(vertical: 2),
  hintText: 'Nuevo elemento',
);

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
  final _addMenuController = OverlayPortalController();
  final _anchorLink = LayerLink();

  bool get _hasChecklist => widget.title != null;

  void _toggleAddMenu() {
    setState(() {
      if (_addMenuController.isShowing) {
        _addMenuController.hide();
      } else {
        _addMenuController.show();
      }
    });
  }

  void _closeAddMenu() {
    if (!_addMenuController.isShowing) return;
    setState(_addMenuController.hide);
  }

  void _confirmAddChecklist(String title) {
    _closeAddMenu();
    final resolved = title.trim().isEmpty ? 'Checklist' : title.trim();
    widget.onChanged(title: resolved, items: widget.items);
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

  Widget _buildAddChecklistPopover({required Widget child}) {
    return OverlayPortal(
      controller: _addMenuController,
      overlayChildBuilder: (context) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ModalBarrier(
              color: Colors.transparent,
              onDismiss: _closeAddMenu,
            ),
            CompositedTransformFollower(
              link: _anchorLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: _AddChecklistPopover(
                onCancel: _closeAddMenu,
                onSubmit: _confirmAddChecklist,
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _anchorLink,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!_hasChecklist) {
      if (!widget.showAddButton) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Checklist', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildAddChecklistPopover(
              child: OutlinedAddChip(
                label: 'Añadir checklist',
                onPressed: _toggleAddMenu,
              ),
            ),
          ),
        ],
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
        const SizedBox(height: 4),
        ...widget.items.map((item) => _ChecklistItemRow(
              item: item,
              onToggle: () => _toggleItem(item.id),
              onTitleChanged: (title) => _updateItemTitle(item.id, title),
              onDelete: () => _removeItem(item.id),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedAddChip(
            label: 'Añadir elemento',
            compact: widget.items.isNotEmpty,
            onPressed: _addItem,
          ),
        ),
      ],
    );
  }
}

class _AddChecklistPopover extends StatefulWidget {
  const _AddChecklistPopover({
    required this.onCancel,
    required this.onSubmit,
  });

  final VoidCallback onCancel;
  final ValueChanged<String> onSubmit;

  @override
  State<_AddChecklistPopover> createState() => _AddChecklistPopoverState();
}

class _AddChecklistPopoverState extends State<_AddChecklistPopover> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'Checklist');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit(_controller.text);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return TapRegion(
      onTapOutside: (_) => widget.onCancel(),
      child: Material(
        elevation: 6,
        color: scheme.surface,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Añadir checklist',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Añadir'),
                  ),
                ),
              ],
            ),
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
  bool _hovering = false;
  bool _focused = false;

  bool get _showActions => _hovering || _focused;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    if (widget.item.title.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_focused != focused) {
      setState(() => _focused = focused);
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
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final completed = widget.item.completed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: _showActions ? AppColors.neutral00 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: completed,
                    onChanged: (_) => widget.onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 3,
                    style: textTheme.bodyMedium?.copyWith(
                      decoration:
                          completed ? TextDecoration.lineThrough : null,
                      color: completed ? AppColors.neutral60 : AppColors.black,
                      height: 1.35,
                    ),
                    decoration: _borderlessFieldDecoration,
                    onChanged: widget.onTitleChanged,
                    onSubmitted: (_) => _focusNode.unfocus(),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _showActions ? 1 : 0.35,
                  child: IconButton(
                    tooltip: 'Eliminar elemento',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.close, size: 16),
                    color: AppColors.neutral40,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
