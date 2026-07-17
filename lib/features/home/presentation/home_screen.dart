import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../global/themes/app_colors.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../../notes/domain/notes_filter.dart';
import '../../notes/domain/notes_query.dart';
import '../../notes/presentation/note_editor_screen.dart';
import '../../notes/presentation/widgets/filter_chips_bar.dart';
import '../../notes/presentation/widgets/note_card.dart';
import '../../notes/presentation/widgets/quick_capture_field.dart';
import '../../profile/presentation/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository});

  final NotesRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  NotesFilter _activeFilter = NotesFilter.all;
  bool _isSearchExpanded = false;

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openProfile(BuildContext context) async {
    final filter = await Navigator.of(context).push<NotesFilter>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(repository: _repo),
      ),
    );
    if (filter != null && mounted) {
      setState(() => _activeFilter = filter);
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    NoteItem? item,
    NoteType initialType = NoteType.note,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(
          item: item,
          initialType: initialType,
          repository: _repo,
        ),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final type = await showModalBottomSheet<NoteType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Nueva nota'),
                onTap: () => Navigator.pop(context, NoteType.note),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Nueva tarea'),
                onTap: () => Navigator.pop(context, NoteType.task),
              ),
            ],
          ),
        );
      },
    );

    if (type == null || !context.mounted) return;
    await _openEditor(context, initialType: type);
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });

    if (_isSearchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  String _formatHeaderDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildEmptyState(String message, TextTheme textTheme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _searchController.text.trim().isNotEmpty
                    ? Icons.search_off_outlined
                    : Icons.edit_note_outlined,
                size: 48,
                color: AppColors.neutral40,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.neutral60,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteList(
    List<NoteItem> items,
    void Function(NoteItem item) onTap,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return NoteCard(
            item: item,
            repository: _repo,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: textTheme.headlineSmall),
      ),
    );
  }

  PreferredSizeWidget _buildAppBarBottom(String searchQuery) {
    if (_isSearchExpanded) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar notas…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.trim().isNotEmpty
                      ? IconButton(
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                ),
              ),
            ),
            Container(height: 1, color: AppColors.neutral20),
          ],
        ),
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.neutral20),
    );
  }

  Widget _buildSliverAppBar(TextTheme textTheme, String searchQuery) {
    final today = _formatHeaderDate(DateTime.now());

    return SliverAppBar(
      pinned: true,
      floating: false,
      titleSpacing: 16,
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Tooltip(
            message: 'Perfil',
            child: InkWell(
              onTap: () => _openProfile(context),
              customBorder: const CircleBorder(),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary00,
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            today,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _isSearchExpanded ? 'Cerrar búsqueda' : 'Buscar',
          onPressed: _toggleSearch,
          icon: Icon(
            _isSearchExpanded ? Icons.close : Icons.search,
            color: _isSearchExpanded
                ? AppColors.primary
                : AppColors.neutral60,
          ),
        ),
        if (!_isSearchExpanded)
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () {},
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.neutral60,
            ),
          ),
      ],
      bottom: _buildAppBarBottom(searchQuery),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final searchQuery = _searchController.text;

    return Scaffold(
      body: ValueListenableBuilder<Box<Map>>(
        valueListenable: _repo.listenable(),
        builder: (context, box, child) {
          final all = _repo.getAll();
          final useSectioned = NotesQuery.useSectionedLayout(
            filter: _activeFilter,
            searchQuery: searchQuery,
          );
          final filtered = NotesQuery.apply(
            items: all,
            filter: _activeFilter,
            searchQuery: searchQuery,
          );
          final pinned = NotesQuery.pinnedFrom(filtered);
          final recent = NotesQuery.recentFrom(filtered);
          final emptyMessage = NotesQuery.emptyMessage(
            filter: _activeFilter,
            searchQuery: searchQuery,
            hasAnyItems: all.isNotEmpty,
          );

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(textTheme, searchQuery),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: QuickCaptureField(repository: _repo),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: FilterChipsBar(
                    activeFilter: _activeFilter,
                    onFilterChanged: (filter) {
                      setState(() => _activeFilter = filter);
                    },
                  ),
                ),
              ),
              if (filtered.isEmpty)
                _buildEmptyState(emptyMessage, textTheme)
              else if (useSectioned) ...[
                if (pinned.isNotEmpty) ...[
                  _buildSectionHeader('Fijadas', textTheme),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: pinned.length,
                      itemBuilder: (context, index) {
                        final item = pinned[index];
                        return NoteCard(
                          item: item,
                          repository: _repo,
                          onTap: () => _openEditor(context, item: item),
                        );
                      },
                    ),
                  ),
                ],
                _buildSectionHeader('Recientes', textTheme),
                if (recent.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'No hay notas recientes',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  _buildNoteList(
                    recent,
                    (item) => _openEditor(context, item: item),
                  ),
              ] else ...[
                _buildSectionHeader(
                  searchQuery.trim().isNotEmpty
                      ? 'Resultados'
                      : _activeFilter.listHeader,
                  textTheme,
                ),
                _buildNoteList(
                  filtered,
                  (item) => _openEditor(context, item: item),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
