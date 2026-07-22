import 'package:flutter/material.dart';

import '../../data/attachments_repository.dart';
import 'attachment_thumb_tile.dart';

/// Bottom sheet grid for “Ver más” attachments.
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
    // Grid cells fill the cross-axis; thumb draws full cell.
    final cell = (MediaQuery.sizeOf(context).width - 32 - 16) / 3;

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
                return AttachmentThumbTile(
                  bytes: repo.bytesFor(item.id),
                  isCover: isCover,
                  width: cell,
                  height: cell,
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
