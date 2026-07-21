import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../global/widgets/app_alerts.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_groups.dart';
import 'note_task_type_switch.dart';

/// Bottom sheet ligero para crear una nota (o tarea sin fecha).
Future<void> showNoteComposeSheet(
  BuildContext context, {
  NotesRepository? repository,
  bool commitTaskToToday = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return NoteComposeSheet(
        repository: repository ?? NotesRepository.instance,
        commitTaskToToday: commitTaskToToday,
      );
    },
  );
}

class NoteComposeSheet extends StatefulWidget {
  const NoteComposeSheet({
    super.key,
    this.repository,
    this.commitTaskToToday = false,
  });

  final NotesRepository? repository;

  /// When true, tasks saved from this sheet get a Hoy commitment (chip Tareas).
  final bool commitTaskToToday;

  @override
  State<NoteComposeSheet> createState() => _NoteComposeSheetState();
}

class _NoteComposeSheetState extends State<NoteComposeSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _titleFocus = FocusNode();
  static const _uuid = Uuid();
  bool _isTask = false;

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  @override
  void initState() {
    super.initState();
    if (widget.commitTaskToToday) {
      _isTask = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String? _taskSavedMessage({required bool committedToToday}) {
    if (!_isTask) return null;
    if (!committedToToday) return 'Tarea guardada';
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
    final commitToToday = isTask && widget.commitTaskToToday;
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
        todayAt: commitToToday ? now : null,
      ),
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final savedMessage =
        _taskSavedMessage(committedToToday: commitToToday) ??
            (isTask ? 'Tarea guardada' : 'Nota guardada');
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                controller: _titleController,
                focusNode: _titleFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Escribe un título',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bodyController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
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
      ),
    );
  }
}
