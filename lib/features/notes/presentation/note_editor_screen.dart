import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../global/themes/app_colors.dart';
import '../../../global/widgets/app_alerts.dart';
import '../data/notes_repository.dart';
import '../data/tags_repository.dart';
import '../domain/note_item.dart';
import '../domain/task_dates.dart';
import '../domain/task_groups.dart';
import 'widgets/tags_editor.dart';
import 'widgets/task_when_field.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.item,
    this.initialType = NoteType.note,
    this.repository,
    this.tagsRepository,
  });

  final NoteItem? item;
  final NoteType initialType;
  final NotesRepository? repository;
  final TagsRepository? tagsRepository;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _titleFocus;
  late NoteType _type;
  late bool _pinned;
  late bool _completed;
  late List<String> _tags;
  DateTime? _dueAt;
  bool _dueHasTime = false;
  bool _todayOn = false;
  static const _uuid = Uuid();

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;
  TagsRepository get _tagsRepo =>
      widget.tagsRepository ?? TagsRepository.instance;

  bool get _isEditing => widget.item != null;

  String get _appBarTitle {
    final isTask = _type == NoteType.task;
    if (_isEditing) {
      return isTask ? 'Editar tarea' : 'Editar nota';
    }
    return isTask ? 'Nueva tarea' : 'Nueva nota';
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _bodyController = TextEditingController(text: item?.body ?? '');
    _titleFocus = FocusNode();
    _type = item?.type ?? widget.initialType;
    _pinned = item?.pinned ?? false;
    _completed = item?.completed ?? false;
    _tags = List<String>.from(item?.tags ?? const []);
    _dueAt = item?.dueAt;
    _dueHasTime = item?.dueHasTime ?? false;
    _todayOn = item?.isTodayCommitment() ?? false;

    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String _todayProgressMessage({required bool isCreate}) {
    final tasks = _repo.getAll().where((n) => n.type == NoteType.task).toList();
    final progress = TaskGroupsQuery.from(tasks).progress;
    final prefix = isCreate ? 'Sumada a Hoy' : 'En Hoy';
    return '$prefix · ${progress.done}/${progress.total} done';
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
    final existing = widget.item;
    final isTask = _type == NoteType.task;
    final isCreate = existing == null;

    await _tagsRepo.ensureTags(_tags);

    DateTime? completedAt;
    if (isTask && _completed) {
      completedAt = existing?.completedAt ?? now;
    }

    final NoteItem toSave;
    if (existing == null) {
      toSave = NoteItem(
        id: _uuid.v4(),
        type: _type,
        title: title,
        body: body,
        pinned: _pinned,
        completed: isTask ? _completed : false,
        createdAt: now,
        updatedAt: now,
        tags: _tags,
        dueAt: isTask ? _dueAt : null,
        dueHasTime: isTask ? _dueHasTime : false,
        todayAt: isTask && _todayOn ? now : null,
        completedAt: isTask ? completedAt : null,
      );
      await _repo.add(toSave);
    } else {
      toSave = existing.copyWith(
        type: _type,
        title: title,
        body: body,
        pinned: _pinned,
        completed: isTask ? _completed : false,
        updatedAt: now,
        tags: _tags,
        dueAt: isTask ? _dueAt : null,
        dueHasTime: isTask ? _dueHasTime : false,
        todayAt: isTask
            ? (_todayOn
                ? (existing.isTodayCommitment(now) ? existing.todayAt : now)
                : null)
            : null,
        completedAt: isTask ? completedAt : null,
      );
      await _repo.update(toSave);
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final showTodayToast =
        isTask && TaskGroupsQuery.belongsToToday(toSave, now: now);
    final toastMessage =
        showTodayToast ? _todayProgressMessage(isCreate: isCreate) : null;

    Navigator.of(context).pop();

    if (toastMessage != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(toastMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _archive() async {
    final item = widget.item;
    if (item == null) return;

    await _repo.archive(item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;

    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar',
      message: '¿Eliminar definitivamente? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );

    if (!confirmed) return;
    await _repo.delete(item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isTask = _type == NoteType.task;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          IconButton(
            tooltip: _pinned ? 'Desfijar' : 'Fijar',
            onPressed: () => setState(() => _pinned = !_pinned),
            icon: Icon(
              _pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _pinned ? AppColors.primary : null,
            ),
          ),
          if (_isEditing) ...[
            IconButton(
              tooltip: 'Archivar',
              onPressed: _archive,
              icon: const Icon(Icons.archive_outlined),
            ),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          TextButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Escribe un título',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Añade detalles (opcional)',
              alignLabelWithHint: true,
            ),
          ),
          if (isTask) ...[
            const SizedBox(height: 24),
            TaskWhenField(
              dueAt: _dueAt,
              dueHasTime: _dueHasTime,
              todayOn: _todayOn,
              onChanged: ({
                required bool todayOn,
                DateTime? dueAt,
                bool dueHasTime = false,
              }) {
                setState(() {
                  _todayOn = todayOn;
                  _dueAt = dueAt;
                  _dueHasTime = dueHasTime;
                });
              },
            ),
          ],
          const SizedBox(height: 24),
          TagsEditor(
            tags: _tags,
            suggestions: {
              ..._tagsRepo.getAllAsSet(),
              ..._repo.getAllTags(),
            },
            onChanged: (tags) => setState(() => _tags = tags),
          ),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text('Es una tarea', style: textTheme.labelLarge),
              subtitle: Text(
                'Muestra un checkbox en la lista',
                style: textTheme.bodySmall,
              ),
              value: isTask,
              onChanged: (value) {
                setState(() {
                  _type = value ? NoteType.task : NoteType.note;
                  if (!value) {
                    _completed = false;
                    _dueAt = null;
                    _dueHasTime = false;
                    _todayOn = false;
                  }
                });
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}
