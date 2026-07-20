import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';
import '../../domain/task_dates.dart';
import 'task_when_field.dart';

/// Actions returned by [showNoteCardContextSheet] (when-chips apply in-place).
enum NoteCardContextAction { pin, duplicate, archive, restore, delete }

Future<NoteCardContextAction?> showNoteCardContextSheet(
  BuildContext context, {
  required NoteItem item,
  NotesRepository? repository,
}) {
  return showModalBottomSheet<NoteCardContextAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return NoteCardContextSheet(
        item: item,
        repository: repository ?? NotesRepository.instance,
      );
    },
  );
}

class NoteCardContextSheet extends StatefulWidget {
  const NoteCardContextSheet({
    super.key,
    required this.item,
    required this.repository,
  });

  final NoteItem item;
  final NotesRepository repository;

  @override
  State<NoteCardContextSheet> createState() => _NoteCardContextSheetState();
}

class _NoteCardContextSheetState extends State<NoteCardContextSheet> {
  late bool _todayOn;
  late DateTime? _dueAt;
  late bool _dueHasTime;
  late int? _reminderMinutesBefore;

  NoteItem get _item => widget.item;
  NotesRepository get _repo => widget.repository;
  bool get _isTask => _item.type == NoteType.task;

  @override
  void initState() {
    super.initState();
    _todayOn = _item.isTodayCommitment();
    _dueAt = _item.dueAt;
    _dueHasTime = _item.dueHasTime;
    _reminderMinutesBefore = _item.reminderMinutesBefore;
  }

  Future<void> _onWhenChanged({
    required bool todayOn,
    DateTime? dueAt,
    bool dueHasTime = false,
    int? reminderMinutesBefore,
  }) async {
    setState(() {
      _todayOn = todayOn;
      _dueAt = dueAt;
      _dueHasTime = dueHasTime;
      _reminderMinutesBefore = reminderMinutesBefore;
    });
    await _repo.applyTaskWhen(
      _item.id,
      todayOn: todayOn,
      dueAt: dueAt,
      dueHasTime: dueHasTime,
      reminderMinutesBefore: reminderMinutesBefore,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required NoteCardContextAction action,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(context, action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _item.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_isTask && !_item.isArchived) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TaskWhenField(
                compact: true,
                dueAt: _dueAt,
                dueHasTime: _dueHasTime,
                todayOn: _todayOn,
                reminderMinutesBefore: _reminderMinutesBefore,
                onChanged: _onWhenChanged,
              ),
            ),
            const Divider(height: 1),
          ],
          _actionTile(
            icon: _item.pinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: _item.pinned ? 'Desfijar' : 'Fijar',
            action: NoteCardContextAction.pin,
          ),
          _actionTile(
            icon: Icons.copy_outlined,
            label: 'Duplicar',
            action: NoteCardContextAction.duplicate,
          ),
          if (!_item.isArchived)
            _actionTile(
              icon: Icons.archive_outlined,
              label: 'Archivar',
              action: NoteCardContextAction.archive,
            )
          else
            _actionTile(
              icon: Icons.unarchive_outlined,
              label: 'Restaurar',
              action: NoteCardContextAction.restore,
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () =>
                  Navigator.pop(context, NoteCardContextAction.delete),
              child: const Text('Eliminar'),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom > 0 ? 0 : 8),
        ],
      ),
    );
  }
}
