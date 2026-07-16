import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../global/themes/app_colors.dart';
import '../data/notes_repository.dart';
import '../domain/note_item.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.item,
    this.initialType = NoteType.note,
    this.repository,
  });

  final NoteItem? item;
  final NoteType initialType;
  final NotesRepository? repository;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late NoteType _type;
  late bool _pinned;
  late bool _completed;
  static const _uuid = Uuid();

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _bodyController = TextEditingController(text: item?.body ?? '');
    _type = item?.type ?? widget.initialType;
    _pinned = item?.pinned ?? false;
    _completed = item?.completed ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un título o contenido')),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.item;

    if (existing == null) {
      await _repo.add(
        NoteItem(
          id: _uuid.v4(),
          type: _type,
          title: title,
          body: body,
          pinned: _pinned,
          completed: _type == NoteType.task ? _completed : false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await _repo.update(
        existing.copyWith(
          type: _type,
          title: title,
          body: body,
          pinned: _pinned,
          completed: _type == NoteType.task ? _completed : false,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Seguro que quieres eliminar esta nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _repo.delete(item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar' : 'Nueva'),
        actions: [
          IconButton(
            tooltip: _pinned ? 'Desfijar' : 'Fijar',
            onPressed: () => setState(() => _pinned = !_pinned),
            icon: Icon(
              _pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _pinned ? AppColors.primary : null,
            ),
          ),
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Es una tarea', style: textTheme.labelLarge),
            subtitle: Text(
              'Muestra un checkbox en la lista',
              style: textTheme.bodySmall,
            ),
            value: _type == NoteType.task,
            onChanged: (value) {
              setState(() {
                _type = value ? NoteType.task : NoteType.note;
                if (!value) _completed = false;
              });
            },
          ),
          if (_type == NoteType.task)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Completada', style: textTheme.labelLarge),
              value: _completed,
              onChanged: (value) {
                setState(() => _completed = value ?? false);
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Opcional',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Contenido',
              hintText: 'Escribe aquí…',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
