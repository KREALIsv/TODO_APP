import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Dropdown reutilizable con buscador, altura máxima con scroll y paginación.
///
/// Pensado para catálogos (tags, categorías, etc.) en cualquier feature.
class SearchableDropdown extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.options,
    required this.onSelected,
    this.hintText = 'Buscar…',
    this.pageSize = 8,
    this.maxHeight = 240,
    this.allowCreate = true,
    this.emptyMessage = 'No hay más opciones',
    this.noResultsMessage = 'Sin resultados',
    this.loadMoreLabel = 'Ver más',
    this.createLabelBuilder,
    this.prefixIcon = const Icon(Icons.search),
    this.expandTooltip = 'Ver opciones',
    this.collapseTooltip = 'Cerrar',
  });

  /// Opciones disponibles (ya filtradas de excluidos por el caller si aplica).
  final Iterable<String> options;

  /// Se llama al elegir una opción, crear una nueva o enviar el campo.
  final ValueChanged<String> onSelected;

  final String hintText;
  final int pageSize;
  final double maxHeight;
  final bool allowCreate;
  final String emptyMessage;
  final String noResultsMessage;
  final String loadMoreLabel;
  final String Function(String query)? createLabelBuilder;
  final Widget? prefixIcon;
  final String expandTooltip;
  final String collapseTooltip;

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _open = false;
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize;
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocus.hasFocus && !_open) {
      setState(() {
        _open = true;
        _visibleCount = widget.pageSize;
      });
    }
  }

  List<String> _filteredOptions() {
    final q = _searchController.text.trim().toLowerCase();
    final list = widget.options
        .where((s) => q.isEmpty || s.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void _select(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    widget.onSelected(trimmed);
    _searchController.clear();
    setState(() => _visibleCount = widget.pageSize);
  }

  void _toggleOpen() {
    setState(() {
      _open = !_open;
      if (_open) {
        _visibleCount = widget.pageSize;
        _searchFocus.requestFocus();
      } else {
        _searchFocus.unfocus();
      }
    });
  }

  void _loadMore() {
    setState(() => _visibleCount += widget.pageSize);
  }

  String _createLabel(String query) {
    return widget.createLabelBuilder?.call(query) ?? 'Crear "$query"';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filteredOptions();
    final visible = filtered.take(_visibleCount).toList();
    final hasMore = filtered.length > visible.length;
    final query = _searchController.text.trim();
    final canCreate = widget.allowCreate &&
        query.isNotEmpty &&
        !filtered.any((s) => s.toLowerCase() == query.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            setState(() {
              _visibleCount = widget.pageSize;
              _open = true;
            });
          },
          onSubmitted: _select,
          onTap: () {
            if (!_open) setState(() => _open = true);
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon,
            isDense: true,
            suffixIcon: IconButton(
              tooltip: _open ? widget.collapseTooltip : widget.expandTooltip,
              onPressed: _toggleOpen,
              icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.surface,
            child: filtered.isEmpty && !canCreate
                ? SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Text(
                        query.isEmpty
                            ? widget.emptyMessage
                            : widget.noResultsMessage,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral40,
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: hasMore
                              ? widget.maxHeight - 44
                              : widget.maxHeight,
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          children: [
                            if (canCreate)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.add, size: 20),
                                title: Text(_createLabel(query)),
                                onTap: () => _select(query),
                              ),
                            ...visible.map(
                              (option) => ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => _select(option),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasMore)
                        TextButton(
                          onPressed: _loadMore,
                          child: Text(
                            '${widget.loadMoreLabel} (${filtered.length - visible.length})',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}
