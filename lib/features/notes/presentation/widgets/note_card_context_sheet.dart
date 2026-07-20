import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/notes_repository.dart';
import '../../domain/date_only.dart';
import '../../domain/note_item.dart';
import '../../domain/task_dates.dart';
import 'task_when_field.dart';

/// Actions returned by [showNoteCardContextSheet] (when-chips apply in-place).
enum NoteCardContextAction { pin, duplicate, archive, restore, delete }

Future<NoteCardContextAction?> showNoteCardContextSheet(
  BuildContext context, {
  required NoteItem item,
  NotesRepository? repository,
  DateTime? actionDay,
}) {
  return showModalBottomSheet<NoteCardContextAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return NoteCardContextSheet(
        item: item,
        repository: repository ?? NotesRepository.instance,
        actionDay: actionDay,
      );
    },
  );
}

class NoteCardContextSheet extends StatefulWidget {
  const NoteCardContextSheet({
    super.key,
    required this.item,
    required this.repository,
    this.actionDay,
  });

  final NoteItem item;
  final NotesRepository repository;
  final DateTime? actionDay;

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
  bool get _showDayActions => _isTask && !_item.isArchived;

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

  Future<void> _applyDayAction(Future<void> Function() action) async {
    await action();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _scheduleTask() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _applyDayAction(
      () => _repo.scheduleTaskToDay(
        _item.id,
        dateOnly(picked),
        fromDay: widget.actionDay,
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    NoteCardContextAction? action,
    VoidCallback? onTap,
  }) {
    assert(action != null || onTap != null);
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap ?? () => Navigator.pop(context, action),
    );
  }

  List<Widget> _bodyChildren(TextTheme textTheme) {
    return [
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
      if (_showDayActions) ...[
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
        _actionTile(
          icon: Icons.chevron_right,
          label: 'Migrar a mañana',
          onTap: () => _applyDayAction(
            () => _repo.migrateTaskToDay(
              _item.id,
              dateOnly(DateTime.now()).add(const Duration(days: 1)),
              fromDay: widget.actionDay,
            ),
          ),
        ),
        _actionTile(
          icon: Icons.event_outlined,
          label: 'Agendar…',
          onTap: _scheduleTask,
        ),
        _actionTile(
          icon: Icons.inbox_outlined,
          label: 'Enviar a Backlog',
          onTap: () => _applyDayAction(
            () => _repo.sendTaskToBacklog(
              _item.id,
              fromDay: widget.actionDay,
            ),
          ),
        ),
        _actionTile(
          icon: Icons.remove_circle_outline,
          label: 'Descartar del día',
          onTap: () => _applyDayAction(
            () => _repo.cancelTaskOnDay(
              _item.id,
              fromDay: widget.actionDay,
            ),
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
    ];
  }

  Widget _deleteButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
        ),
        onPressed: () => Navigator.pop(context, NoteCardContextAction.delete),
        child: const Text('Eliminar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    // Tasks have many actions: bounded height + scroll + sticky Eliminar.
    if (_showDayActions) {
      return SafeArea(
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(children: _bodyChildren(textTheme)),
              ),
              const Divider(height: 1),
              _deleteButton(),
            ],
          ),
        ),
      );
    }

    // Notes stay compact (no overflow).
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._bodyChildren(textTheme),
          const Divider(height: 1),
          _deleteButton(),
          SizedBox(height: MediaQuery.paddingOf(context).bottom > 0 ? 0 : 8),
        ],
      ),
    );
  }
}
