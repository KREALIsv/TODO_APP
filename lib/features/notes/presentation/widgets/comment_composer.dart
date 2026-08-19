import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../../../global/widgets/app_loading.dart';
import '../../data/attachments_repository.dart';
import '../../domain/note_comment.dart';
import '../../domain/note_item.dart';
import 'attachment_actions.dart';

class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.noteId,
    required this.enabled,
    required this.noteType,
    required this.onSubmit,
  });

  final String noteId;
  final bool enabled;
  final NoteType noteType;
  final Future<void> Function({
    required String body,
    required List<PickedImageBytes> images,
  }) onSubmit;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  final _pending = <PickedImageBytes>[];
  var _busy = false;

  bool get _canSend {
    if (!widget.enabled || _busy) return false;
    final text = _controller.text.trim();
    if (text.length > NoteComment.maxBodyLength) return false;
    return text.isNotEmpty || _pending.isNotEmpty;
  }

  String get _hint {
    if (!widget.enabled) {
      return widget.noteType == NoteType.task
          ? 'Guarda la tarea para comentar'
          : 'Guarda la nota para comentar';
    }
    return 'Escribe un comentario…';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addImage(ImageSource source) async {
    if (!widget.enabled || _busy) return;
    if (_pending.length >= AttachmentsRepository.maxImagesPerComment) {
      await AppAlerts.show(
        context,
        message: 'Máximo 4 imágenes por comentario',
        type: AppAlertType.warning,
      );
      return;
    }
    try {
      final picked = await pickImageBytes(source: source);
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _pending.add(picked));
    } catch (_) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo añadir la imagen',
        type: AppAlertType.error,
      );
    }
  }

  Future<void> _showAddSheet() async {
    if (!widget.enabled) return;
    await showAddImageSourceSheet(context, onSelected: _addImage);
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        body: _controller.text.trim(),
        images: List<PickedImageBytes>.from(_pending),
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _pending.clear());
    } on StateError catch (e) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: e.message,
        type: AppAlertType.warning,
      );
    } catch (_) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo enviar el comentario',
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pending.isNotEmpty) ...[
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pending.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = _pending[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        image.bytes,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Quitar',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _pending.removeAt(index)),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled && !_busy,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _hint,
                  alignLabelWithHint: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Añadir imagen',
              onPressed: widget.enabled && !_busy ? _showAddSheet : null,
              icon: const Icon(Icons.attach_file),
            ),
            _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppLoading(size: 18),
                  )
                : TextButton(
                    onPressed: _canSend ? _send : null,
                    child: const Text('Enviar'),
                  ),
          ],
        ),
        if (_controller.text.trim().length > NoteComment.maxBodyLength)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'El comentario es demasiado largo',
              style: textTheme.bodySmall?.copyWith(
                color: AppSurface.secondary(context),
              ),
            ),
          ),
      ],
    );
  }
}
