import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../global/widgets/app_alerts.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';

class QuickCaptureField extends StatefulWidget {
  const QuickCaptureField({super.key, this.repository});

  final NotesRepository? repository;

  @override
  State<QuickCaptureField> createState() => _QuickCaptureFieldState();
}

class _QuickCaptureFieldState extends State<QuickCaptureField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  static const _uuid = Uuid();

  NotesRepository get _repo => widget.repository ?? NotesRepository.instance;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    await _repo.add(
      NoteItem(
        id: _uuid.v4(),
        type: NoteType.note,
        title: '',
        body: text,
        pinned: false,
        completed: false,
        createdAt: now,
        updatedAt: now,
      ),
    );

    _controller.clear();
    _focusNode.unfocus();

    if (!mounted) return;
    await AppAlerts.show(
      context,
      message: 'Nota guardada',
      type: AppAlertType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: 'Escribe una nota…',
        prefixIcon: const Icon(Icons.edit_note_outlined),
        suffixIcon: IconButton(
          tooltip: 'Guardar',
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded),
        ),
      ),
    );
  }
}
