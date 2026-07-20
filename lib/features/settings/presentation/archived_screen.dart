import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../global/themes/app_colors.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../../notes/presentation/note_editor_screen.dart';
import '../../notes/presentation/widgets/swipeable_note_card.dart';
import 'widgets/list_background_layer.dart';

class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key, this.repository});

  final NotesRepository? repository;

  NotesRepository get _repo => repository ?? NotesRepository.instance;

  Future<void> _openEditor(BuildContext context, NoteItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(
          item: item,
          repository: _repo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Archivadas'),
        backgroundColor: isDark ? const Color(0xFF1C2128) : AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListBackgroundScaffoldBody(
        child: ValueListenableBuilder<Box<Map>>(
          valueListenable: _repo.listenable(),
          builder: (context, box, _) {
            final items = _repo.getArchived();
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay elementos archivados',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.neutral60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return SwipeableNoteCard(
                  item: item,
                  repository: _repo,
                  onTap: () => _openEditor(context, item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
