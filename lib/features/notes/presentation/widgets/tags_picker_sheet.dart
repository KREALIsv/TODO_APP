import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/notes_repository.dart';
import '../../data/tags_repository.dart';
import '../../domain/tag_colors.dart';
import 'tag_color_picker_sheet.dart';
import 'tag_pill.dart';

enum _TagsPickerPage { list, editor }

class _EditorArgs {
  const _EditorArgs.create({this.prefill = ''})
      : editingTag = null,
        isCreate = true;

  const _EditorArgs.edit(this.editingTag)
      : prefill = editingTag ?? '',
        isCreate = false;

  final bool isCreate;
  final String? editingTag;
  final String prefill;
}

/// Ventana emergente para buscar, seleccionar, editar y crear etiquetas.
Future<void> showTagsPickerSheet(
  BuildContext context, {
  required List<String> selectedTags,
  required Set<String> catalog,
  required ValueChanged<List<String>> onChanged,
  TagsRepository? tagsRepository,
  NotesRepository? notesRepository,
  int maxTags = 10,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return _TagsPickerSheet(
        selectedTags: selectedTags,
        catalog: catalog,
        onChanged: onChanged,
        tagsRepository: tagsRepository ?? TagsRepository.instance,
        notesRepository: notesRepository ?? NotesRepository.instance,
        maxTags: maxTags,
      );
    },
  );
}

class _TagsPickerSheet extends StatefulWidget {
  const _TagsPickerSheet({
    required this.selectedTags,
    required this.catalog,
    required this.onChanged,
    required this.tagsRepository,
    required this.notesRepository,
    required this.maxTags,
  });

  final List<String> selectedTags;
  final Set<String> catalog;
  final ValueChanged<List<String>> onChanged;
  final TagsRepository tagsRepository;
  final NotesRepository notesRepository;
  final int maxTags;

  @override
  State<_TagsPickerSheet> createState() => _TagsPickerSheetState();
}

class _TagsPickerSheetState extends State<_TagsPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _selected;
  late Set<String> _catalog;
  static const int _pageSize = 8;
  int _visibleCount = _pageSize;

  _TagsPickerPage _page = _TagsPickerPage.list;
  _EditorArgs? _editorArgs;

  TagsRepository get _repo => widget.tagsRepository;
  NotesRepository get _notesRepo => widget.notesRepository;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedTags);
    _catalog = {...widget.catalog, ..._repo.getAllAsSet()};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(List<String>.from(_selected));

  void _openCreate({String prefill = ''}) {
    if (_selected.length >= widget.maxTags) {
      AppAlerts.show(
        context,
        message: 'Máximo ${widget.maxTags} etiquetas',
        type: AppAlertType.warning,
      );
      return;
    }
    setState(() {
      _page = _TagsPickerPage.editor;
      _editorArgs = _EditorArgs.create(prefill: prefill);
    });
  }

  void _openEdit(String tag) {
    setState(() {
      _page = _TagsPickerPage.editor;
      _editorArgs = _EditorArgs.edit(tag);
    });
  }

  void _backToList() {
    setState(() {
      _page = _TagsPickerPage.list;
      _editorArgs = null;
    });
  }

  bool _isSelected(String tag) {
    final key = tag.toLowerCase();
    return _selected.any((t) => t.toLowerCase() == key);
  }

  List<String> _filteredCatalog() {
    final q = _searchController.text.trim().toLowerCase();
    final list = _catalog
        .where((t) => q.isEmpty || t.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        final aSel = _isSelected(a);
        final bSel = _isSelected(b);
        if (aSel != bSel) return aSel ? -1 : 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return list;
  }

  Future<void> _toggle(String tag) async {
    final key = tag.toLowerCase();
    final already = _selected.any((t) => t.toLowerCase() == key);

    if (already) {
      setState(() {
        _selected = _selected.where((t) => t.toLowerCase() != key).toList();
      });
      _emit();
      return;
    }

    if (_selected.length >= widget.maxTags) {
      AppAlerts.show(
        context,
        message: 'Máximo ${widget.maxTags} etiquetas',
        type: AppAlertType.warning,
      );
      return;
    }

    await _repo.ensureTags([tag]);
    setState(() => _selected = [..._selected, tag]);
    _emit();
  }

  Future<void> _onEditorCompleted(TagColorPickerResult result) async {
    final args = _editorArgs;
    if (args == null) return;

    if (args.isCreate) {
      final existsInNote = _selected.any(
        (t) => t.toLowerCase() == result.title.toLowerCase(),
      );
      await _repo.ensureTag(
        result.title,
        colorId: result.colorId,
        opacity: result.opacity,
      );
      setState(() {
        _catalog = {..._catalog, result.title};
        _searchController.clear();
        _visibleCount = _pageSize;
        if (!existsInNote && _selected.length < widget.maxTags) {
          _selected = [..._selected, result.title];
        }
        _page = _TagsPickerPage.list;
        _editorArgs = null;
      });
      _emit();
      return;
    }

    final tag = args.editingTag!;
    if (result.deleted) {
      await _repo.remove(tag);
      await _notesRepo.removeTag(tag);
      setState(() {
        _catalog = _catalog
            .where((t) => t.toLowerCase() != tag.toLowerCase())
            .toSet();
        _selected = _selected
            .where((t) => t.toLowerCase() != tag.toLowerCase())
            .toList();
        _page = _TagsPickerPage.list;
        _editorArgs = null;
      });
      _emit();
      return;
    }

    final renamed = result.title.trim();
    final sameName = renamed.toLowerCase() == tag.toLowerCase();
    if (!sameName) {
      final ok = await _repo.rename(tag, renamed);
      if (!ok) {
        if (mounted) {
          AppAlerts.show(
            context,
            message: 'Ya existe una etiqueta con ese nombre',
            type: AppAlertType.warning,
          );
        }
        return;
      }
      await _notesRepo.renameTag(tag, renamed);
      setState(() {
        _catalog = {
          for (final t in _catalog)
            if (t.toLowerCase() == tag.toLowerCase()) renamed else t,
        };
        _selected = [
          for (final t in _selected)
            if (t.toLowerCase() == tag.toLowerCase()) renamed else t,
        ];
      });
    }

    await _repo.setStyle(
      renamed,
      colorId: result.colorId,
      opacity: result.opacity,
    );
    setState(() {
      _page = _TagsPickerPage.list;
      _editorArgs = null;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _page == _TagsPickerPage.list
              ? KeyedSubtree(
                  key: const ValueKey('tags-list'),
                  child: _buildListPage(context),
                )
              : KeyedSubtree(
                  key: ValueKey(
                    'tags-editor-${_editorArgs?.editingTag ?? 'create'}',
                  ),
                  child: _buildEditorPage(),
                ),
        ),
      ),
    );
  }

  Widget _buildEditorPage() {
    final args = _editorArgs!;
    final editing = args.editingTag;

    return TagColorPickerPanel(
      initialTitle: args.isCreate ? args.prefill : (editing ?? ''),
      initialColorId: editing == null
          ? TagColors.swatches.first.id
          : _repo.getColorId(editing),
      initialOpacity: editing == null
          ? TagColors.defaultOpacity
          : _repo.getOpacity(editing),
      allowDelete: !args.isCreate,
      showBackButton: true,
      sheetTitle: args.isCreate ? 'Crear etiqueta' : 'Editar etiqueta',
      confirmLabel: args.isCreate ? 'Crear' : 'Guardar',
      onBack: _backToList,
      onCompleted: _onEditorCompleted,
    );
  }

  Widget _buildListPage(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filteredCatalog();
    final visible = filtered.take(_visibleCount).toList();
    final hasMore = filtered.length > visible.length;
    final query = _searchController.text.trim();
    final canCreateFromQuery = query.isNotEmpty &&
        !_catalog.any((t) => t.toLowerCase() == query.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Text(
                  'Etiquetas',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              setState(() => _visibleCount = _pageSize);
            },
            decoration: const InputDecoration(
              hintText: 'Buscar etiquetas…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty && !canCreateFromQuery
              ? Center(
                  child: Text(
                    query.isEmpty ? 'No hay etiquetas aún' : 'Sin resultados',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral40,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    if (canCreateFromQuery)
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text('Crear "$query"'),
                        onTap: () => _openCreate(prefill: query),
                      ),
                    if (visible.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          'Etiquetas',
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.neutral60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...visible.map((tag) {
                        final selected = _isSelected(tag);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(tag),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TagPill(
                                    label: tag,
                                    colors: _repo.colorFor(tag),
                                    onTap: () => _toggle(tag),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () => _openEdit(tag),
                                icon: const Icon(Icons.edit_outlined),
                                color: AppColors.neutral60,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _visibleCount += _pageSize);
                          },
                          child: Text(
                            'Mostrar más etiquetas (${filtered.length - visible.length})',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: OutlinedButton.icon(
            onPressed: () => _openCreate(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Crear una etiqueta nueva'),
          ),
        ),
      ],
    );
  }
}
