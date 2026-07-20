import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../global/themes/app_colors.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../../notes/domain/notes_filter.dart';
import '../../notes/domain/notes_query.dart';
import '../../notes/domain/task_groups.dart';
import '../../notes/presentation/note_editor_screen.dart';
import '../../notes/presentation/widgets/clock_refresh.dart';
import '../../notes/presentation/widgets/filter_chips_bar.dart';
import '../../notes/presentation/widgets/grouped_tasks_sliver.dart';
import '../../notes/presentation/widgets/note_compose_sheet.dart';
import '../../notes/presentation/widgets/quick_capture_field.dart';
import '../../notes/presentation/widgets/swipeable_note_card.dart';
import '../../notes/presentation/widgets/task_section_header.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/widgets/list_background_layer.dart';

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
  bool _completedExpanded = false;
  late final ClockRefreshController _clock;
  DateTime _now = DateTime.now();

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  @override
  void initState() {
    super.initState();
    _clock = ClockRefreshController(
      repository: _repo,
      onTick: () {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      },
    );
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
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

  Future<void> _openSettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(repository: _repo),
      ),
    );
  }

  bool get _fabCreatesTask => _activeFilter == NotesFilter.tasks;

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

  Future<void> _openNoteComposeSheet(BuildContext context) {
    return showNoteComposeSheet(context, repository: _repo);
  }

  Future<void> _onFabPressed() {
    if (_fabCreatesTask) {
      return _openEditor(context, initialType: NoteType.task);
    }
    return _openNoteComposeSheet(context);
  }

  Future<void> _onFabLongPress() {
    if (_fabCreatesTask) {
      return _openNoteComposeSheet(context);
    }
    return _openEditor(context, initialType: NoteType.task);
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
    void Function(NoteItem item) onTap, {
    double bottomPadding = 88,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return SwipeableNoteCard(
            item: item,
            repository: _repo,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: TaskSectionHeader(title: title),
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
    final today = _formatHeaderDate(_now);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF1C2128) : AppColors.white;

    return SliverAppBar(
      pinned: true,
      floating: false,
      titleSpacing: 16,
      backgroundColor: barColor,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Tooltip(
            message: 'Perfil',
            child: InkWell(
              onTap: () => _openProfile(context),
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  color: scheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            today,
            style: textTheme.labelLarge?.copyWith(
              color: scheme.primary,
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
            color: _isSearchExpanded ? scheme.primary : AppColors.neutral60,
          ),
        ),
        if (!_isSearchExpanded)
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _openSettings(context),
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
      backgroundColor: Colors.transparent,
      body: ListBackgroundScaffoldBody(
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<Box<Map>>(
            valueListenable: _repo.listenable(),
            builder: (context, box, child) {
          // Re-arm the due-time ticker when the dataset changes.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _clock.schedule();
          });

          final isArchivedFilter = _activeFilter == NotesFilter.archived;
          final all =
              isArchivedFilter ? _repo.getArchived() : _repo.getAll();
          final useSectioned = NotesQuery.useSectionedLayout(
            filter: _activeFilter,
            searchQuery: searchQuery,
          );
          final useGrouped = NotesQuery.useGroupedTasksLayout(
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
          final groups = useGrouped
              ? TaskGroupsQuery.from(filtered, now: _now)
              : null;

          return SlidableAutoCloseBehavior(
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(textTheme, searchQuery),
                if (!isArchivedFilter)
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
                        setState(() {
                          _activeFilter = filter;
                          _completedExpanded = false;
                        });
                      },
                    ),
                  ),
                ),
                if (useGrouped && groups != null && !groups.isEmpty)
                  ...buildGroupedTasksSlivers(
                    groups: groups,
                    onOpen: (item) => _openEditor(context, item: item),
                    repository: _repo,
                    textTheme: textTheme,
                    completedExpanded: _completedExpanded,
                    onToggleCompleted: () {
                      setState(
                        () => _completedExpanded = !_completedExpanded,
                      );
                    },
                  )
                else if (filtered.isEmpty ||
                    (useGrouped && groups != null && groups.isEmpty))
                  _buildEmptyState(emptyMessage, textTheme)
                else if (useSectioned) ...[
                  if (pinned.isNotEmpty) ...[
                    _buildSectionHeader('Fijadas'),
                    _buildNoteList(
                      pinned,
                      (item) => _openEditor(context, item: item),
                      bottomPadding: 0,
                    ),
                  ],
                  _buildSectionHeader('Recientes'),
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
                  ),
                  _buildNoteList(
                    filtered,
                    (item) => _openEditor(context, item: item),
                  ),
                ],
              ],
            ),
          );
          },
        ),
        ),
      ),
      floatingActionButton: Tooltip(
        message: _fabCreatesTask ? 'Nueva tarea' : 'Nueva nota',
        child: Semantics(
          button: true,
          label: _fabCreatesTask ? 'Nueva tarea' : 'Nueva nota',
          hint: _fabCreatesTask
              ? 'Mantén pulsado para crear una nota'
              : 'Mantén pulsado para crear una tarea',
          child: GestureDetector(
            onLongPress: _onFabLongPress,
            child: FloatingActionButton(
              onPressed: _onFabPressed,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
  }
}
