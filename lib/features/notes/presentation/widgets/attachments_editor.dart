import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../../../global/widgets/outlined_add_chip.dart';
import '../../data/attachments_repository.dart';
import '../../domain/note_attachment.dart';
import '../attachment_viewer_screen.dart';
import 'attachment_actions.dart';
import 'attachment_format.dart';
import 'attachment_thumb_tile.dart';
import 'attachments_grid_sheet.dart';

/// Editor section: thumbnail strip, add, see-more grid, cover controls.
class AttachmentsEditor extends StatefulWidget {
  const AttachmentsEditor({
    super.key,
    required this.noteId,
    required this.coverAttachmentId,
    required this.onCoverChanged,
    this.onAttachmentAdded,
    this.repository,
  });

  final String noteId;
  final String? coverAttachmentId;
  final ValueChanged<String?> onCoverChanged;

  /// Fired after a new image is stored (for draft-session tracking).
  final ValueChanged<String>? onAttachmentAdded;
  final AttachmentsRepository? repository;

  @override
  State<AttachmentsEditor> createState() => _AttachmentsEditorState();
}

class _AttachmentsEditorState extends State<AttachmentsEditor> {
  final _picker = ImagePicker();
  bool _busy = false;

  AttachmentsRepository get _repo =>
      widget.repository ?? AttachmentsRepository.instance;

  Future<void> _addFrom(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: AttachmentsRepository.maxDecodeEdge.toDouble(),
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final created = await _repo.addImage(
        noteId: widget.noteId,
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      widget.onAttachmentAdded?.call(created.id);
      if (widget.coverAttachmentId == null) {
        widget.onCoverChanged(created.id);
      }
    } on StateError catch (e) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: e.message,
        type: AppAlertType.warning,
      );
    } catch (e) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo añadir la imagen',
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _addFrom(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  _addFrom(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openViewer(List<NoteAttachment> items, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentViewerScreen(
          noteId: widget.noteId,
          initialIndex: index,
          coverAttachmentId: widget.coverAttachmentId,
          onCoverChanged: widget.onCoverChanged,
          repository: _repo,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openGrid(List<NoteAttachment> items) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return AttachmentsGridSheet(
          noteId: widget.noteId,
          coverAttachmentId: widget.coverAttachmentId,
          onCoverChanged: widget.onCoverChanged,
          onOpenViewer: (index) {
            Navigator.pop(context);
            _openViewer(items, index);
          },
          repository: _repo,
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteAttachment(NoteAttachment item) async {
    final deleted = await confirmAndDeleteAttachment(
      context,
      item: item,
      coverAttachmentId: widget.coverAttachmentId,
      onCoverChanged: widget.onCoverChanged,
      attachments: _repo,
    );
    if (deleted && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<Box<Map>>(
      valueListenable: _repo.listenable(),
      builder: (context, box, _) {
        final items = _repo.forNote(widget.noteId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Adjuntos', style: textTheme.labelLarge),
                ),
                if (items.isNotEmpty)
                  TextButton.icon(
                    onPressed: _busy ? null : _showAddSheet,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
              ],
            ),
            if (items.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedAddChip(
                  label: 'Añadir imagen',
                  onPressed: _busy ? null : _showAddSheet,
                ),
              )
            else ...[
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Align(
                        alignment: Alignment.center,
                        child: OutlinedAddChip(
                          label: 'Añadir imagen',
                          compact: true,
                          onPressed: _busy ? null : _showAddSheet,
                        ),
                      );
                    }
                    final item = items[index];
                    final isCover = item.id == widget.coverAttachmentId;
                    final thumb = attachmentStripThumbSize(
                      imageWidth: item.width,
                      imageHeight: item.height,
                    );
                    return AttachmentThumbTile(
                      bytes: _repo.bytesFor(item.id),
                      isCover: isCover,
                      width: thumb.width,
                      height: thumb.height,
                      onTap: () => _openViewer(items, index),
                      onLongPress: () => _showThumbMenu(item),
                    );
                  },
                ),
              ),
              if (items.length > 4) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _openGrid(items),
                    child: Text(
                      'Ver más (${items.length})',
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _showThumbMenu(NoteAttachment item) async {
    final isCover = item.id == widget.coverAttachmentId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isCover ? Icons.star_outline : Icons.star,
                ),
                title: Text(
                  isCover ? 'Quitar portada' : 'Usar como portada',
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onCoverChanged(isCover ? null : item.id);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Eliminar'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteAttachment(item);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
