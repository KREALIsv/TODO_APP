import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/io/share_bytes_file.dart';
import '../../../core/theme/app_surface.dart';
import '../../../global/themes/tokens.dart';
import '../../../global/widgets/app_alerts.dart';
import '../../settings/presentation/widgets/list_background_layer.dart';
import '../data/attachments_repository.dart';
import '../domain/note_attachment.dart';
import 'widgets/attachment_actions.dart';
import 'widgets/attachment_format.dart';

/// Full-screen attachment viewer with zoom, metadata, download and delete.
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
      await shareBytesAsFile(
        bytes: bytes,
        fileName: item.fileName,
        mimeType: item.mimeType,
        subject: item.fileName,
      );
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
    setState(() => _busy = true);
    try {
      final deleted = await confirmAndDeleteAttachment(
        context,
        item: item,
        coverAttachmentId: _coverId,
        onCoverChanged: (id) {
          _coverId = id;
          widget.onCoverChanged(id);
        },
        attachments: _repo,
      );
      if (!deleted || !mounted) return;

      final remaining = _repo.forNote(widget.noteId);
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
