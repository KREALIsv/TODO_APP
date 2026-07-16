import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../global/themes/app_colors.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_item.dart';
import '../../notes/presentation/note_editor_screen.dart';
import '../../notes/presentation/widgets/note_card.dart';
import '../../notes/presentation/widgets/quick_capture_field.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.repository});

  final NotesRepository? repository;

  NotesRepository get _repo => repository ?? NotesRepository.instance;

  Future<void> _openEditor(
    BuildContext context, {
    NoteItem? item,
    NoteType initialType = NoteType.note,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(
          item: item,
          initialType: initialType,
          repository: _repo,
        ),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final type = await showModalBottomSheet<NoteType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Nueva nota'),
                onTap: () => Navigator.pop(context, NoteType.note),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Nueva tarea'),
                onTap: () => Navigator.pop(context, NoteType.task),
              ),
            ],
          ),
        );
      },
    );

    if (type == null || !context.mounted) return;
    await _openEditor(context, initialType: type);
  }

  String _formatHeaderDate(DateTime date) {
    // Avoid intl dependency — format manually to keep deps minimal.
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final today = _formatHeaderDate(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<Box<Map>>(
          valueListenable: _repo.listenable(),
          builder: (context, box, child) {
            final all = _repo.getAll();
            final pinned = all.where((item) => item.pinned).toList();
            final recent = all.where((item) => !item.pinned).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary00,
                          child: Icon(
                            Icons.person_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            today,
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ajustes',
                          onPressed: () {},
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: AppColors.neutral60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: QuickCaptureField(repository: _repo),
                  ),
                ),
                if (all.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_note_outlined,
                              size: 48,
                              color: AppColors.neutral40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tu primera nota está a un tap',
                              style: textTheme.bodyLarge?.copyWith(
                                color: AppColors.neutral60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (pinned.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Fijadas', style: textTheme.headlineSmall),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: pinned.length,
                        itemBuilder: (context, index) {
                          final item = pinned[index];
                          return NoteCard(
                            item: item,
                            repository: _repo,
                            onTap: () => _openEditor(context, item: item),
                          );
                        },
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Recientes', style: textTheme.headlineSmall),
                    ),
                  ),
                  if (recent.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No hay notas recientes',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      sliver: SliverList.builder(
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final item = recent[index];
                          return NoteCard(
                            item: item,
                            repository: _repo,
                            onTap: () => _openEditor(context, item: item),
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
