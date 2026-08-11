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
  bool _isTask = false;

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialIsTask) {
      _isTask = true;
    }
    // Only auto-scroll the description: the title sits at the top of the
    // sheet. ensureVisible/scrollPadding on the title + iOS Safari's native
    // focus scroll double-shifts content and hides the inputs.
    _bodyFocus.addListener(() {
      if (_bodyFocus.hasFocus) _ensureFieldVisible(_bodyFieldKey);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Keyboard open/close: keep the description above the IME when focused.
    // Skip the title — it's already at the top; scrolling it causes iOS
    // Safari to overshoot and leave empty space above the keyboard.
    if (_bodyFocus.hasFocus) {
      _ensureFieldVisible(_bodyFieldKey);
    }
  }

  void _ensureFieldVisible(GlobalKey fieldKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = fieldKey.currentContext;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.15,
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
    final bottomInset = sheetKeyboardBottomInset(context);
    final maxHeight = sheetMaxHeight(
      context,
      maxHeightFraction: 0.92,
      minHeight: 240,
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
              textInputAction: TextInputAction.next,
              // Keep small: large scrollPadding on the top field makes
              // Flutter/Safari scroll the sheet past the title on iOS.
              scrollPadding: const EdgeInsets.only(bottom: 24),
              onSubmitted: (_) => _bodyFocus.requestFocus(),
              decoration: const InputDecoration(
                hintText: 'Escribe un título',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: _bodyFieldKey,
              controller: _bodyController,
              focusNode: _bodyFocus,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
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
