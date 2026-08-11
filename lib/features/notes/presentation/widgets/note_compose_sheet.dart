import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/layout/keyboard_insets.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/notes_repository.dart';
import '../../domain/date_only.dart';
import '../../domain/note_item.dart';
import '../../domain/task_groups.dart';
import 'note_task_type_switch.dart';

/// Bottom sheet ligero para crear una nota (o tarea con compromiso de hoy).
Future<void> showNoteComposeSheet(
  BuildContext context, {
  NotesRepository? repository,
  bool initialIsTask = false,
  DateTime? contextDay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return NoteComposeSheet(
        repository: repository ?? NotesRepository.instance,
        initialIsTask: initialIsTask,
        contextDay: contextDay,
      );
    },
  );
}

class NoteComposeSheet extends StatefulWidget {
  const NoteComposeSheet({
    super.key,
    this.repository,
    this.initialIsTask = false,
    this.contextDay,
  });

  final NotesRepository? repository;
  final bool initialIsTask;

  /// Calendar day the new item should belong to (defaults to today).
  final DateTime? contextDay;

  @override
  State<NoteComposeSheet> createState() => _NoteComposeSheetState();
}

class _NoteComposeSheetState extends State<NoteComposeSheet>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _titleFieldKey = GlobalKey();
  final _bodyFieldKey = GlobalKey();
  static const _uuid = Uuid();
  static const _titleAutofocusDelay = Duration(milliseconds: 350);
  static const _paddingSettleDelay = Duration(milliseconds: 130);
  bool _isTask = false;
  double? _baselineViewHeight;
  /// Last focus-aware bottom pad (for unpadded field projection).
  double _lastBottomInset = 0;

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  void _onTitleFocusChanged() {
    _onFocusChanged();
    // Only scroll when the title was pushed off-screen (e.g. after body
    // ensureVisible). Avoid eager ensureVisible — it shrinks measured
    // overlap and can zero the pad while the sheet is still lifted.
    if (_titleFocus.hasFocus) {
      _ensureFieldVisible(_titleFieldKey, onlyIfObscured: true);
    }
  }

  void _onBodyFocusChanged() {
    _onFocusChanged();
    if (_bodyFocus.hasFocus) _ensureFieldVisible(_bodyFieldKey);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialIsTask) {
      _isTask = true;
    }
    _titleFocus.addListener(_onTitleFocusChanged);
    _bodyFocus.addListener(_onBodyFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureBaselineViewHeight();
      // Wait for the sheet slide-in + first layout before focusing. Races
      // between autofocus, IME metrics, and padding caused overshoot on iOS
      // and Android when the title was focused immediately.
      Future<void>.delayed(_titleAutofocusDelay, () {
        if (mounted) _titleFocus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleFocus.removeListener(_onTitleFocusChanged);
    _bodyFocus.removeListener(_onBodyFocusChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
    // Remeasure after layout and after AnimatedPadding settles so a
    // description → title switch does not keep a stale "already clear" read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    Future<void>.delayed(_paddingSettleDelay, () {
      if (mounted) setState(() {});
    });
  }

  void _captureBaselineViewHeight() {
    if (!mounted) return;
    final height = MediaQuery.sizeOf(context).height;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset == 0) {
      _baselineViewHeight = height;
    }
  }

  @override
  void didChangeMetrics() {
    _captureBaselineViewHeight();
    if (_bodyFocus.hasFocus) {
      _ensureFieldVisible(_bodyFieldKey);
    } else if (_titleFocus.hasFocus) {
      _ensureFieldVisible(_titleFieldKey, onlyIfObscured: true);
    }
    if (mounted) setState(() {});
  }

  double? _focusedFieldBottomGlobal() {
    if (_bodyFocus.hasFocus) return globalFieldBottom(_bodyFieldKey);
    if (_titleFocus.hasFocus) return globalFieldBottom(_titleFieldKey);
    return null;
  }

  void _ensureFieldVisible(
    GlobalKey fieldKey, {
    bool onlyIfObscured = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = fieldKey.currentContext;
      if (fieldContext == null) return;
      if (onlyIfObscured) {
        final bottom = globalFieldBottom(fieldKey);
        final box = fieldContext.findRenderObject();
        if (bottom == null || box is! RenderBox || !box.hasSize) return;
        final top = box.localToGlobal(Offset.zero).dy;
        final media = MediaQuery.of(this.context);
        final keyboardTop =
            media.size.height - media.viewInsets.bottom - 12;
        if (top >= 0 && bottom <= keyboardTop) return;
      }
      // Title sits near the top of the sheet — keep alignment low so iOS
      // does not overscroll the header off-screen.
      final alignment = identical(fieldKey, _titleFieldKey) ? 0.0 : 0.15;
      Scrollable.ensureVisible(
        fieldContext,
        alignment: alignment,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String _taskSavedMessage(DateTime day) {
    final isToday = dateOnly(day) == dateOnly(DateTime.now());
    if (!isToday) {
      return 'Agendada para ${formatDayMonth(day)}';
    }
    final progress = TaskGroupsQuery.from(
      _repo.getAll().where((n) => n.type == NoteType.task).toList(),
    ).progress;
    if (progress.hideIfZero) return 'Sumada a Hoy';
    return 'Sumada a Hoy · ${progress.done}/${progress.total} done';
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      await AppAlerts.show(
        context,
        message: 'Escribe un título',
        type: AppAlertType.warning,
      );
      return;
    }

    final day = dateOnly(widget.contextDay ?? DateTime.now());
    final timestamp = timestampForContextDay(day);
    final isTask = _isTask;
    final taskDates = isTask ? taskDatesForContextDay(day) : null;
    await _repo.add(
      NoteItem(
        id: _uuid.v4(),
        type: isTask ? NoteType.task : NoteType.note,
        title: title,
        body: body,
        pinned: false,
        completed: false,
        createdAt: timestamp,
        updatedAt: timestamp,
        todayAt: taskDates?.todayAt,
        dueAt: taskDates?.dueAt,
      ),
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final savedMessage =
        isTask ? _taskSavedMessage(day) : 'Nota guardada';
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(savedMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final previousBottomInset = _lastBottomInset;
    final bottomInset = sheetKeyboardBottomInset(
      context,
      baselineViewHeight: _baselineViewHeight,
      focusedFieldBottomGlobal: _focusedFieldBottomGlobal(),
      // Field global Y already includes this lift — project to unpadded space.
      currentBottomPad: previousBottomInset,
    );
    _lastBottomInset = bottomInset;
    final maxHeight = sheetMaxHeight(
      context,
      maxHeightFraction: 0.92,
      minHeight: isLandscape ? 180 : 240,
      baselineViewHeight: _baselineViewHeight,
    );

    // Pad above an overlaying IME and size the sheet to its content.
    // ListView.shrinkWrap keeps the sheet compact — a non-shrink-wrapped
    // scroll view stretches to fill the safe area, parking the title at the
    // top of the screen with a large empty gap (Android "rises even though
    // the keyboard isn't covering the title", and iOS overshoot).
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              _isTask ? 'Nueva tarea' : 'Nueva nota',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: _titleFieldKey,
              controller: _titleController,
              focusNode: _titleFocus,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 8,
              // Keep small: large scrollPadding on the top field makes
              // Flutter/Safari scroll the sheet past the title on iOS.
              scrollPadding: const EdgeInsets.only(bottom: 24),
              decoration: const InputDecoration(
                hintText: 'Escribe un título',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: _bodyFieldKey,
              controller: _bodyController,
              focusNode: _bodyFocus,
              textCapitalization: TextCapitalization.sentences,
              minLines: isLandscape ? 2 : 3,
              maxLines: isLandscape ? 4 : 6,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              decoration: const InputDecoration(
                hintText: 'Añade detalles (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            NoteTaskTypeSwitch(
              value: _isTask,
              onChanged: (value) => setState(() => _isTask = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
