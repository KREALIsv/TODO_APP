import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/layout/adaptive_breakpoints.dart';
import '../../../core/theme/app_surface.dart';
import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/date_only.dart';
import '../../notes/domain/day_log.dart';
import '../../notes/domain/note_item.dart';
import '../../notes/domain/notes_filter.dart';
import '../../notes/domain/notes_query.dart';
import '../../notes/domain/task_groups.dart';
import '../../notes/presentation/note_editor_screen.dart';
import '../../notes/presentation/widgets/clock_refresh.dart';
import '../../notes/presentation/widgets/day_replay_sliver.dart';
import '../../notes/presentation/widgets/filter_chips_bar.dart';
import '../../notes/presentation/widgets/grouped_tasks_sliver.dart';
import '../../notes/presentation/widgets/note_compose_sheet.dart';
import '../../notes/presentation/widgets/quick_capture_field.dart';
import '../../notes/presentation/widgets/swipeable_note_card.dart';
import '../../notes/presentation/widgets/task_section_header.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/widgets/list_background_layer.dart';
import '../../shell/presentation/desktop_panel_state.dart';
import 'widgets/day_selector_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.dayEntriesRepository,
    this.activeFilter,
    this.onFilterChanged,
    this.embeddedInShell = false,
    this.onOpenSettings,
    this.onRegisterDayReset,
    this.onOpenNoteEditor,
    this.selectedNoteId,
  });

  final NotesRepository? repository;
  final DayEntriesRepository? dayEntriesRepository;
  final NotesFilter? activeFilter;
  final ValueChanged<NotesFilter>? onFilterChanged;
  final bool embeddedInShell;
  final VoidCallback? onOpenSettings;
  final ValueChanged<VoidCallback>? onRegisterDayReset;
  final ValueChanged<NoteEditorRequest>? onOpenNoteEditor;
  final String? selectedNoteId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  NotesFilter _activeFilter = NotesFilter.all;
  bool _isSearchExpanded = false;
  GroupedTasksExpansion _groupedExpansion = const GroupedTasksExpansion();
  bool _pinnedSectionExpanded = true;
  bool _ofDaySectionExpanded = true;
  late final ClockRefreshController _clock;
  DateTime _now = DateTime.now();
  late DateTime _selectedDay;
  DateTime? _backfillRequestedFor;

  NotesFilter get _effectiveFilter => widget.activeFilter ?? _activeFilter;

  void _setActiveFilter(NotesFilter filter) {
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(filter);
    } else {
      setState(() => _activeFilter = filter);
    }
    _resetSectionExpansion();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeFilter != null &&
        widget.activeFilter != oldWidget.activeFilter) {
      _resetSectionExpansion();
    }
  }
  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;
  DayEntriesRepository get _dayEntries =>
      widget.dayEntriesRepository ?? DayEntriesRepository.instance;

  @override
  void initState() {
    super.initState();
    _selectedDay = dateOnly(_now);
    _clock = ClockRefreshController(
      repository: _repo,
      onTick: () {
        if (!mounted) return;
        setState(() {
          final previousToday = dateOnly(_now);
          _now = DateTime.now();
          if (dateOnly(_selectedDay) == previousToday) {
            _selectedDay = dateOnly(_now);
          }
        });
      },
    );
    _clock.start();
    widget.onRegisterDayReset?.call(_resetSelectedDayToToday);
  }

  @override
  void dispose() {
    _clock.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSelectedDayChanged(DateTime day) {
    setState(() {
      _selectedDay = dateOnly(day);
      _backfillRequestedFor = null;
    });
  }

  void _maybeBackfillPastDay(DateTime day) {
    final key = dateOnly(day);
    final today = dateOnly(_now);
    if (!key.isBefore(today)) return;
    if (_backfillRequestedFor == key) return;
    _backfillRequestedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _dayEntries.backfillDayIfEmpty(
        day: key,
        notes: [..._repo.getAll(), ..._repo.getArchived()],
      );
    });
  }

  void _resetSelectedDayToToday() {
    _onSelectedDayChanged(dateOnly(DateTime.now()));
  }

  Future<void> _openProfile(BuildContext context) async {
    final filter = await Navigator.of(context).push<NotesFilter>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          repository: _repo,
          onResetSelectedDay: _resetSelectedDayToToday,
        ),
      ),
    );
    if (filter != null && mounted) {
      _setActiveFilter(filter);
    }
  }

  Future<void> _openSettings(BuildContext context) {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          repository: _repo,
          onResetSelectedDay: _resetSelectedDayToToday,
        ),
      ),
    );
  }

  bool get _fabCreatesTask => _effectiveFilter == NotesFilter.tasks;

  Future<void> _openEditor(
    BuildContext context, {
    NoteItem? item,
    NoteType initialType = NoteType.note,
    bool initialTodayOn = false,
  }) {
    if (widget.onOpenNoteEditor != null) {
      widget.onOpenNoteEditor!(
        NoteEditorRequest(item: item, initialType: initialType),
      );
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(
          item: item,
          initialType: initialType,
          initialTodayOn: initialTodayOn,
          repository: _repo,
        ),
      ),
    );
  }

  Future<void> _openNoteComposeSheet(BuildContext context) {
    if (widget.onOpenNoteEditor != null) {
      return _openEditor(context, initialType: NoteType.note);
    }
    return showNoteComposeSheet(
      context,
      repository: _repo,
      commitTaskToToday: _effectiveFilter == NotesFilter.tasks,
    );
  }

  Future<void> _onFabPressed() {
    if (_fabCreatesTask) {
      return _openEditor(
        context,
        initialType: NoteType.task,
        initialTodayOn: true,
      );
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

  Widget _buildEmptyState(
    BuildContext context,
    String message,
    TextTheme textTheme,
  ) {
    final scheme = Theme.of(context).colorScheme;
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
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
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
            selected: widget.selectedNoteId == item.id,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    bool collapsible = true,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return SliverToBoxAdapter(
      child: TaskSectionHeader(
        title: title,
        expanded: collapsible ? expanded : null,
        onToggle: collapsible ? onToggle : null,
      ),
    );
  }

  void _resetSectionExpansion() {
    _groupedExpansion = const GroupedTasksExpansion();
    _pinnedSectionExpanded = true;
    _ofDaySectionExpanded = true;
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
            Container(height: 1, color: AppSurface.divider(context)),
          ],
        ),
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppSurface.divider(context)),
    );
  }

  Widget _buildSliverAppBar(TextTheme textTheme, String searchQuery) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showProfileLeading = !widget.embeddedInShell;
    final showSettingsAction = widget.embeddedInShell
        ? false
        : AdaptiveBreakpoints.showDesktopAffordances(context);

    return SliverAppBar(
      pinned: true,
      floating: false,
      centerTitle: true,
      toolbarHeight: kToolbarHeight,
      titleSpacing: 0,
      leadingWidth: showProfileLeading ? 56 : 16,
      backgroundColor: AppSurface.panelOverlay(context),
      surfaceTintColor: Colors.transparent,
      leading: showProfileLeading
          ? Center(
              child: Tooltip(
                message: showSettingsAction
                    ? 'Perfil'
                    : 'Perfil · mantén para Ajustes',
                child: InkWell(
                  onTap: () => _openProfile(context),
                  onLongPress: showSettingsAction
                      ? null
                      : () => _openSettings(context),
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
            )
          : null,
      title: DaySelectorHeader(
        selectedDay: _selectedDay,
        today: _now,
        onDayChanged: _onSelectedDayChanged,
        textStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
        ),
      ),
      actions: [
        if (showSettingsAction)
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _openSettings(context),
            icon: Icon(
              Icons.settings_outlined,
              color: AppSurface.secondary(context),
            ),
          ),
        IconButton(
          tooltip: _isSearchExpanded ? 'Cerrar búsqueda' : 'Buscar',
          onPressed: _toggleSearch,
          icon: Icon(
            _isSearchExpanded ? Icons.close : Icons.search,
            color: _isSearchExpanded
                ? scheme.primary
                : AppSurface.secondary(context),
          ),
        ),
      ],
      bottom: _buildAppBarBottom(searchQuery),
    );
  }

  List<Widget> _buildLiveBodySlivers({
    required TextTheme textTheme,
    required String searchQuery,
    required List<NoteItem> all,
  }) {
    final useSectioned = NotesQuery.useSectionedLayout(
      filter: _effectiveFilter,
      searchQuery: searchQuery,
    );
    final useGrouped = NotesQuery.useGroupedTasksLayout(
      filter: _effectiveFilter,
      searchQuery: searchQuery,
    );
    final filtered = NotesQuery.apply(
      items: all,
      filter: _effectiveFilter,
      searchQuery: searchQuery,
    );
    final pinned = NotesQuery.pinnedFrom(filtered);
    final ofDay = NotesQuery.ofDayFrom(filtered, _now, now: _now);
    final emptyMessage = NotesQuery.emptyMessage(
      filter: _effectiveFilter,
      searchQuery: searchQuery,
      hasAnyItems: all.isNotEmpty,
    );
    final groups =
        useGrouped ? TaskGroupsQuery.from(filtered, now: _now) : null;

    return [
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
            activeFilter: _effectiveFilter,
            onFilterChanged: _setActiveFilter,
          ),
        ),
      ),
      if (useGrouped && groups != null && !groups.isEmpty)
        ...buildGroupedTasksSlivers(
          groups: groups,
          onOpen: (item) => _openEditor(context, item: item),
          repository: _repo,
          textTheme: textTheme,
          expansion: _groupedExpansion,
          selectedNoteId: widget.selectedNoteId,
          onToggleSection: (section) {
            setState(() {
              _groupedExpansion = _groupedExpansion.toggle(section);
            });
          },
        )
      else if (filtered.isEmpty ||
          (useGrouped && groups != null && groups.isEmpty))
        _buildEmptyState(context, emptyMessage, textTheme)
      else if (useSectioned) ...() {
        final hasPinned = pinned.isNotEmpty;
        final collapsible = hasPinned;
        return [
          if (hasPinned) ...[
            _buildSectionHeader(
              'Fijadas',
              collapsible: collapsible,
              expanded: _pinnedSectionExpanded,
              onToggle: () => setState(
                () => _pinnedSectionExpanded = !_pinnedSectionExpanded,
              ),
            ),
            if (!collapsible || _pinnedSectionExpanded)
              _buildNoteList(
                pinned,
                (item) => _openEditor(context, item: item),
                bottomPadding: 0,
              ),
          ],
          _buildSectionHeader(
            'Del día',
            collapsible: collapsible,
            expanded: _ofDaySectionExpanded,
            onToggle: () => setState(
              () => _ofDaySectionExpanded = !_ofDaySectionExpanded,
            ),
          ),
          if (!collapsible || _ofDaySectionExpanded)
            if (ofDay.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Nada más del día',
                    style: textTheme.bodyMedium,
                  ),
                ),
              )
            else
              _buildNoteList(
                ofDay,
                (item) => _openEditor(context, item: item),
              ),
        ];
      }() else ...[
        _buildSectionHeader(
          searchQuery.trim().isNotEmpty
              ? 'Resultados'
              : _effectiveFilter.listHeader,
          collapsible: false,
          expanded: true,
          onToggle: () {},
        ),
        _buildNoteList(
          filtered,
          (item) => _openEditor(context, item: item),
        ),
      ],
    ];
  }

  List<Widget> _buildReplaySlivers(DateTime day) {
    _maybeBackfillPastDay(day);
    final entries = _dayEntries.entriesForDay(day);
    final notesById = <String, NoteItem>{
      for (final n in [..._repo.getAll(), ..._repo.getArchived()]) n.id: n,
    };
    final rows = resolveDayLogRows(entries: entries, notesById: notesById);
    return [
      DayReplaySliver(
        rows: rows,
        onOpen: (item) => _openEditor(context, item: item),
      ),
    ];
  }

  List<Widget> _buildPlanSlivers(DateTime day) {
    final items = planNotesForDay(_repo.getAll(), day);
    return [
      DayPlanSliver(
        day: day,
        items: items,
        onOpen: (item) => _openEditor(context, item: item),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final searchQuery = _searchController.text;
    final today = dateOnly(_now);
    final selected = dateOnly(_selectedDay);
    final isLiveDay = selected == today;
    final isPastDay = selected.isBefore(today);

    final scrollBody = _buildScrollBody(
      textTheme: textTheme,
      searchQuery: searchQuery,
      isLiveDay: isLiveDay,
      isPastDay: isPastDay,
      selected: selected,
    );

    final body = widget.embeddedInShell
        ? scrollBody
        : ListBackgroundScaffoldBody(child: scrollBody);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: body,
      floatingActionButton: isLiveDay
          ? Tooltip(
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
            )
          : null,
    );
  }

  Widget _buildScrollBody({
    required TextTheme textTheme,
    required String searchQuery,
    required bool isLiveDay,
    required bool isPastDay,
    required DateTime selected,
  }) {
    return SafeArea(
      top: false,
      child: ValueListenableBuilder<Box<Map>>(
        valueListenable: _repo.listenable(),
        builder: (context, notesBox, _) {
          return ValueListenableBuilder<Box<Map>>(
            valueListenable: _dayEntries.listenable(),
            builder: (context, dayBox, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _clock.schedule();
              });

              final isArchivedFilter =
                  _effectiveFilter == NotesFilter.archived;
              final all =
                  isArchivedFilter ? _repo.getArchived() : _repo.getAll();

              final bodySlivers = isLiveDay
                  ? _buildLiveBodySlivers(
                      textTheme: textTheme,
                      searchQuery: searchQuery,
                      all: all,
                    )
                  : isPastDay
                      ? _buildReplaySlivers(selected)
                      : _buildPlanSlivers(selected);

              return SlidableAutoCloseBehavior(
                child: CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(textTheme, searchQuery),
                    ...bodySlivers,
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
