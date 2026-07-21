import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../data/attachments_repository.dart';
import '../../domain/note_attachment.dart';

/// Editor section: thumbnail strip, add, see-more grid, cover controls.
class AttachmentsEditor extends StatefulWidget {
  const AttachmentsEditor({
    super.key,
    required this.noteId,
    required this.coverAttachmentId,
    required this.onCoverChanged,
    this.repository,
  });

  final String noteId;
  final String? coverAttachmentId;
  final ValueChanged<String?> onCoverChanged;
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
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar imagen',
      message: '¿Eliminar esta imagen?',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _repo.delete(item.id);
    if (widget.coverAttachmentId == item.id) {
      final remaining = _repo.forNote(widget.noteId);
      widget.onCoverChanged(remaining.isEmpty ? null : remaining.first.id);
    }
    if (mounted) setState(() {});
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
                  child: Text('Adjuntos', style: textTheme.titleSmall),
                ),
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
                child: _AddAttachmentButton(
                  onPressed: _busy ? null : _showAddSheet,
                ),
              )
            else ...[
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return _AddTile(onTap: _busy ? null : _showAddSheet);
                    }
                    final item = items[index];
                    final isCover = item.id == widget.coverAttachmentId;
                    return _ThumbTile(
                      bytes: _repo.bytesFor(item.id),
                      isCover: isCover,
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
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
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

/// Same outlined pill shape as the empty-state "Añadir etiqueta" button.
class _AddAttachmentButton extends StatelessWidget {
  const _AddAttachmentButton({this.onPressed});

  final VoidCallback? onPressed;

  static final _radius = BorderRadius.circular(10);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.neutral00,
        shape: RoundedRectangleBorder(
          borderRadius: _radius,
          side: const BorderSide(color: AppColors.neutral20),
        ),
        child: InkWell(
          borderRadius: _radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.neutral60),
                const SizedBox(width: 4),
                Text(
                  'Añadir imagen',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.neutral60,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ThemeTokens.borderRadius,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: ThemeTokens.borderRadius,
          border: Border.all(color: AppColors.neutral20),
          color: AppColors.neutral00,
        ),
        child: const Icon(Icons.add, color: AppColors.neutral60),
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.bytes,
    required this.isCover,
    required this.onTap,
    this.onLongPress,
  });

  final Uint8List? bytes;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: ThemeTokens.borderRadius,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: ThemeTokens.borderRadius,
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.neutral20,
              child: bytes == null
                  ? const Icon(Icons.broken_image_outlined)
                  : Image.memory(bytes!, fit: BoxFit.cover),
            ),
          ),
          if (isCover)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class AttachmentsGridSheet extends StatelessWidget {
  const AttachmentsGridSheet({
    super.key,
    required this.noteId,
    required this.coverAttachmentId,
    required this.onCoverChanged,
    required this.onOpenViewer,
    this.repository,
  });

  final String noteId;
  final String? coverAttachmentId;
  final ValueChanged<String?> onCoverChanged;
  final ValueChanged<int> onOpenViewer;
  final AttachmentsRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AttachmentsRepository.instance;
    final items = repo.forNote(noteId);
    final height = MediaQuery.sizeOf(context).height * 0.7;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Fotos · ${items.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isCover = item.id == coverAttachmentId;
                return _ThumbTile(
                  bytes: repo.bytesFor(item.id),
                  isCover: isCover,
                  onTap: () => onOpenViewer(index),
                  onLongPress: () {
                    onCoverChanged(isCover ? null : item.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentViewerScreen extends StatefulWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.noteId,
    required this.initialIndex,
    required this.coverAttachmentId,
    required this.onCoverChanged,
    this.repository,
  });

  final String noteId;
  final int initialIndex;
  final String? coverAttachmentId;
  final ValueChanged<String?> onCoverChanged;
  final AttachmentsRepository? repository;

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  late final PageController _controller;
  late int _index;
  late String? _coverId;

  AttachmentsRepository get _repo =>
      widget.repository ?? AttachmentsRepository.instance;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _coverId = widget.coverAttachmentId;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _repo.forNote(widget.noteId);
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Sin imágenes')),
      );
    }
    final safeIndex = _index.clamp(0, items.length - 1);
    final current = items[safeIndex];
    final isCover = current.id == _coverId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${safeIndex + 1} / ${items.length}'),
        actions: [
          IconButton(
            tooltip: isCover ? 'Quitar portada' : 'Usar como portada',
            onPressed: () {
              final next = isCover ? null : current.id;
              setState(() => _coverId = next);
              widget.onCoverChanged(next);
            },
            icon: Icon(isCover ? Icons.star : Icons.star_outline),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final bytes = _repo.bytesFor(items[i].id);
          if (bytes == null) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
            );
          }
          return InteractiveViewer(
            child: Center(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () {
              final next = isCover ? null : current.id;
              setState(() => _coverId = next);
              widget.onCoverChanged(next);
            },
            child: Text(isCover ? 'Quitar portada' : 'Usar como portada'),
          ),
        ),
      ),
    );
  }
}
