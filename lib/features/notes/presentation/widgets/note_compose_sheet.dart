import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/layout/keyboard_insets.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_groups.dart';
import 'note_task_type_switch.dart';

/// Bottom sheet ligero para crear una nota (o tarea con compromiso de hoy).
Future<void> showNoteComposeSheet(
  BuildContext context, {
  NotesRepository? repository,
  bool initialIsTask = false,
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
      );
    },
  );
}

class NoteComposeSheet extends StatefulWidget {
  const NoteComposeSheet({
    super.key,
    this.repository,
    this.initialIsTask = false,
  });

  final NotesRepository? repository;
  final bool initialIsTask;

  @override
  State<NoteComposeSheet> createState() => _NoteComposeSheetState();
}

class _NoteComposeSheetState extends State<NoteComposeSheet> {
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
    if (widget.initialIsTask) {
      _isTask = true;
    }
    _titleFocus.addListener(() => _ensureFieldVisible(_titleFieldKey));
    _bodyFocus.addListener(() => _ensureFieldVisible(_bodyFieldKey));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _ensureFieldVisible(GlobalKey fieldKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = fieldKey.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String _taskSavedMessage() {
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

    final now = DateTime.now();
    final isTask = _isTask;
    await _repo.add(
      NoteItem(
        id: _uuid.v4(),
        type: isTask ? NoteType.task : NoteType.note,
        title: title,
        body: body,
        pinned: false,
        completed: false,
        createdAt: now,
        updatedAt: now,
        todayAt: isTask ? now : null,
      ),
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final savedMessage =
        isTask ? _taskSavedMessage() : 'Nota guardada';
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      scrollPadding: const EdgeInsets.only(bottom: 120),
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
