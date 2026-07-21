import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_surface.dart';
import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../../settings/presentation/widgets/list_background_layer.dart';
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
  final _focusNode = FocusNode();
  final _transform = TransformationController();
  bool _zoomed = false;
  bool _busy = false;

  AttachmentsRepository get _repo =>
      widget.repository ?? AttachmentsRepository.instance;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _coverId = widget.coverAttachmentId;
    _controller = PageController(initialPage: widget.initialIndex);
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transform.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _zoomed && mounted) {
      setState(() => _zoomed = zoomed);
    }
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
    if (_zoomed) setState(() => _zoomed = false);
  }

  void _close() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  void _toggleCover(NoteAttachment current) {
    final next = current.id == _coverId ? null : current.id;
    setState(() => _coverId = next);
    widget.onCoverChanged(next);
  }

  Future<void> _download(NoteAttachment item) async {
    if (_busy) return;
    final bytes = _repo.bytesFor(item.id);
    if (bytes == null) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo descargar la imagen',
        type: AppAlertType.error,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                name: item.fileName,
                mimeType: item.mimeType,
              ),
            ],
            subject: item.fileName,
          ),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${item.fileName}');
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                file.path,
                name: item.fileName,
                mimeType: item.mimeType,
              ),
            ],
            subject: item.fileName,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await AppAlerts.show(
        context,
        message: 'No se pudo descargar la imagen',
        type: AppAlertType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(NoteAttachment item) async {
    if (_busy) return;
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar imagen',
      message: '¿Eliminar esta imagen?',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final wasCover = item.id == _coverId;
      await _repo.delete(item.id);
      final remaining = _repo.forNote(widget.noteId);
      if (wasCover) {
        final nextCover = remaining.isEmpty ? null : remaining.first.id;
        _coverId = nextCover;
        widget.onCoverChanged(nextCover);
      }
      if (remaining.isEmpty) {
        _close();
        return;
      }
      final nextIndex = _index.clamp(0, remaining.length - 1);
      _resetZoom();
      setState(() => _index = nextIndex);
      if (_controller.hasClients) {
        _controller.jumpToPage(nextIndex);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: ValueListenableBuilder<Box<Map>>(
          valueListenable: _repo.listenable(),
          builder: (context, box, _) {
            final items = _repo.forNote(widget.noteId);
            if (items.isEmpty) {
              return Scaffold(
                appBar: AppBar(leading: BackButton(onPressed: _close)),
                body: const Center(child: Text('Sin imágenes')),
              );
            }
            final safeIndex = _index.clamp(0, items.length - 1);
            final current = items[safeIndex];
            final isCover = current.id == _coverId;

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: AppSurface.panelOverlay(context),
                foregroundColor: AppSurface.title(context),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: BackButton(onPressed: _close),
                title: Text(
                  '${safeIndex + 1} / ${items.length}',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppSurface.title(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Descargar',
                    onPressed: _busy ? null : () => _download(current),
                    icon: const Icon(Icons.download_outlined),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: _busy ? null : () => _delete(current),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  IconButton(
                    tooltip: isCover ? 'Quitar portada' : 'Usar como portada',
                    onPressed: _busy ? null : () => _toggleCover(current),
                    icon: Icon(
                      isCover ? Icons.star : Icons.star_outline,
                      color: isCover
                          ? scheme.primary
                          : AppSurface.title(context),
                    ),
                  ),
                ],
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const ListBackgroundLayer(),
                  ColoredBox(
                    color: scheme.surface.withValues(
                      alpha: AppSurface.isDark(context) ? 0.72 : 0.78,
                    ),
                  ),
                  PageView.builder(
                    controller: _controller,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: items.length,
                    onPageChanged: (i) {
                      _resetZoom();
                      setState(() => _index = i);
                    },
                    itemBuilder: (context, i) {
                      final bytes = _repo.bytesFor(items[i].id);
                      if (bytes == null) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppSurface.mutedIcon(context),
                            size: 48,
                          ),
                        );
                      }
                      return InteractiveViewer(
                        transformationController:
                            i == safeIndex ? _transform : null,
                        minScale: 1,
                        maxScale: 5,
                        clipBehavior: Clip.none,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: ClipRRect(
                              borderRadius: ThemeTokens.borderRadius,
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              bottomNavigationBar: Material(
                color: AppSurface.panelOverlay(context),
                elevation: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${formatAttachmentAddedAt(current.createdAt)}'
                          ' · ${formatAttachmentByteSize(current.byteSize)}',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppSurface.secondary(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed:
                              _busy ? null : () => _toggleCover(current),
                          icon: Icon(
                            isCover ? Icons.star : Icons.star_outline,
                          ),
                          label: Text(
                            isCover
                                ? 'Quitar portada'
                                : 'Usar como portada',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Absolute local date+time for attachment metadata (`21/07/2026 · 15:18`).
String formatAttachmentAddedAt(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

String formatAttachmentByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    final text = kb < 10 ? kb.toStringAsFixed(1) : kb.toStringAsFixed(0);
    return '$text KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
