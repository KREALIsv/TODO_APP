import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../data/day_entries_repository.dart';
import '../../data/notes_repository.dart';
import '../../domain/date_only.dart';
import '../../domain/day_view_query.dart';
import '../../domain/note_item.dart';
import '../../domain/task_dates.dart';
import '../../domain/task_when_save_hint.dart';
import 'resolve_remove_from_day.dart';
import 'task_day_history_section.dart';
import 'task_when_field.dart';
import 'task_when_save_hint_banner.dart';

/// Actions returned by [showNoteCardContextSheet] (when-chips apply in-place).
enum NoteCardContextAction { pin, duplicate, archive, restore, delete }

Future<NoteCardContextAction?> showNoteCardContextSheet(
  BuildContext context, {
  required NoteItem item,
  NotesRepository? repository,
  DateTime? actionDay,
  ValueChanged<DateTime>? onNavigateToDay,
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
        onNavigateToDay: onNavigateToDay,
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
    this.onNavigateToDay,
  });

  final NoteItem item;
  final NotesRepository repository;
  final DateTime? actionDay;
  final ValueChanged<DateTime>? onNavigateToDay;

  @override
  State<NoteCardContextSheet> createState() => _NoteCardContextSheetState();
}

class _NoteCardContextSheetState extends State<NoteCardContextSheet> {
  late bool _todayOn;
  late DateTime? _dueAt;
  late bool _dueHasTime;
  late int? _reminderMinutesBefore;
  String? _changeHint;

  NoteItem get _item => widget.item;
  NotesRepository get _repo => widget.repository;
  bool get _isTask => _item.type == NoteType.task;
  bool get _showDayActions => _isTask && !_item.isArchived;
  bool get _hasDayCommitment => _todayOn || _dueAt != null;

  bool get _showRemoveFromDay {
    if (!_showDayActions) return false;
    final day = widget.actionDay;
    if (day == null) return _hasDayCommitment;
    final entry = DayEntriesRepository.instance.findForNoteDay(_item.id, day);
    return DayViewQuery.canRemoveFromDay(_item, day, entry: entry);
  }

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
    final previousTodayOn = _todayOn;
    final previousDueAt = _dueAt;
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
    if (!mounted) return;
    setState(() {
      _changeHint = taskWhenChangeHint(
        previous: _item.copyWith(
          todayAt: previousTodayOn ? (_item.todayAt ?? DateTime.now()) : null,
          dueAt: previousDueAt,
        ),
        nextTodayOn: todayOn,
        nextDueAt: dueAt,
      );
    });
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
        if (_changeHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TaskWhenSaveHintBanner(message: _changeHint!),
          ),
        const Divider(height: 1),
        TaskDayHistorySection(
          noteId: _item.id,
          onDayTap: widget.onNavigateToDay == null
              ? null
              : (day) {
                  Navigator.of(context).pop();
                  widget.onNavigateToDay!(day);
                },
        ),
        const Divider(height: 1),
        _actionTile(
          icon: Icons.event_outlined,
          label: 'Agendar otro día',
          onTap: _scheduleTask,
        ),
        if (_showRemoveFromDay) _removeFromDayButton(),
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

  /// Drops the task's calendar commitment for the action / viewed day.
  Widget _removeFromDayButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: OutlinedButton(
        onPressed: () async {
          final fromDay = await resolveRemoveFromDay(
            context,
            item: _item,
            preferredDay: widget.actionDay,
          );
          if (fromDay == null) return;
          await _applyDayAction(
            () => _repo.cancelTaskOnDay(_item.id, fromDay: fromDay),
          );
        },
        child: Text(
          widget.actionDay == null
              ? 'Quitar del día'
              : 'Quitar del ${formatDayMonth(widget.actionDay!)}',
        ),
      ),
    );
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
