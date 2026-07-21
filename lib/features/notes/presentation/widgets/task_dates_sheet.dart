import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/layout/keyboard_insets.dart';
import '../../../../global/themes/app_colors.dart';
import '../../data/task_reminders_service.dart';
import '../../domain/date_only.dart';
import '../../domain/reminder_offset.dart';
import 'tappable_value_field.dart';

class TaskDatesSheetResult {
  const TaskDatesSheetResult({
    required this.dueAt,
    required this.dueHasTime,
    required this.reminderMinutesBefore,
    this.clearDate = false,
  });

  final DateTime? dueAt;
  final bool dueHasTime;
  final int? reminderMinutesBefore;
  final bool clearDate;
}

enum _TaskDatesPage { form, date, time }

/// Panel de detalle de fecha (PRD §6.12): fecha, hora y recordatorio.
Future<TaskDatesSheetResult?> showTaskDatesSheet(
  BuildContext context, {
  DateTime? dueAt,
  bool dueHasTime = false,
  int? reminderMinutesBefore,
}) {
  return showModalBottomSheet<TaskDatesSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return TaskDatesSheet(
        dueAt: dueAt,
        dueHasTime: dueHasTime,
        reminderMinutesBefore: reminderMinutesBefore,
      );
    },
  );
}

class TaskDatesSheet extends StatefulWidget {
  const TaskDatesSheet({
    super.key,
    this.dueAt,
    this.dueHasTime = false,
    this.reminderMinutesBefore,
  });

  final DateTime? dueAt;
  final bool dueHasTime;
  final int? reminderMinutesBefore;

  @override
  State<TaskDatesSheet> createState() => _TaskDatesSheetState();
}

class _TaskDatesSheetState extends State<TaskDatesSheet> {
  late DateTime _dueAt;
  late bool _dueHasTime;
  int? _reminderMinutesBefore;

  _TaskDatesPage _page = _TaskDatesPage.form;
  late DateTime _draftDate;
  late TimeOfDay _draftTime;

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  void initState() {
    super.initState();
    final seed = widget.dueAt ?? DateTime.now();
    _dueHasTime = widget.dueAt != null && widget.dueHasTime;
    _dueAt = _dueHasTime ? seed : dateOnly(seed);
    _reminderMinutesBefore =
        widget.dueAt == null ? null : widget.reminderMinutesBefore;
    _draftDate = dateOnly(_dueAt);
    _draftTime = _dueHasTime
        ? TimeOfDay.fromDateTime(_dueAt)
        : TimeOfDay.fromDateTime(DateTime.now());
  }

  String _formatDate() {
    final d = _dueAt;
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String _formatTime() {
    final hour = _dueAt.hour;
    final minute = _dueAt.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute ${isPm ? 'PM' : 'AM'}';
  }

  void _openDate() {
    setState(() {
      _draftDate = dateOnly(_dueAt);
      _page = _TaskDatesPage.date;
    });
  }

  void _openTime() {
    setState(() {
      _draftTime = _dueHasTime
          ? TimeOfDay.fromDateTime(_dueAt)
          : TimeOfDay.fromDateTime(DateTime.now());
      _page = _TaskDatesPage.time;
    });
  }

  void _backToForm() {
    setState(() => _page = _TaskDatesPage.form);
  }

  void _confirmDate() {
    setState(() {
      _dueAt = _dueHasTime
          ? DateTime(
              _draftDate.year,
              _draftDate.month,
              _draftDate.day,
              _dueAt.hour,
              _dueAt.minute,
            )
          : DateTime(_draftDate.year, _draftDate.month, _draftDate.day);
      _page = _TaskDatesPage.form;
    });
  }

  void _confirmTime() {
    setState(() {
      _dueHasTime = true;
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        _draftTime.hour,
        _draftTime.minute,
      );
      _page = _TaskDatesPage.form;
    });
  }

  void _clearTime() {
    setState(() {
      _dueHasTime = false;
      _dueAt = dateOnly(_dueAt);
    });
  }

  Future<void> _pickReminder(int? minutes) async {
    if (minutes != null) {
      final granted = await TaskRemindersService.instance.ensurePermission();
      if (!mounted) return;
      if (!granted && TaskRemindersService.instance.isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Activa las notificaciones en Ajustes para recibir recordatorios',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _reminderMinutesBefore = minutes);
  }

  void _save() {
    Navigator.of(context).pop(
      TaskDatesSheetResult(
        dueAt: _dueAt,
        dueHasTime: _dueHasTime,
        reminderMinutesBefore: _reminderMinutesBefore,
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(
      const TaskDatesSheetResult(
        dueAt: null,
        dueHasTime: false,
        reminderMinutesBefore: null,
        clearDate: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = sheetKeyboardBottomInset(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: switch (_page) {
              _TaskDatesPage.form => KeyedSubtree(
                  key: const ValueKey('dates-form'),
                  child: _buildFormPage(context),
                ),
              _TaskDatesPage.date => KeyedSubtree(
                  key: const ValueKey('dates-date'),
                  child: _buildDatePage(context),
                ),
              _TaskDatesPage.time => KeyedSubtree(
                  key: const ValueKey('dates-time'),
                  child: _buildTimePage(context),
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader({
    required String title,
    VoidCallback? onBack,
    VoidCallback? onClose,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Volver',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildFooter(List<Widget> children) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildFormPage(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSheetHeader(
            title: 'Fecha',
            onClose: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Vencimiento', style: textTheme.labelLarge),
                const SizedBox(height: 8),
                TappableValueField(
                  value: _formatDate(),
                  onTap: _openDate,
                ),
                const SizedBox(height: 16),
                Text('Hora', style: textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TappableValueField(
                        value: _dueHasTime ? _formatTime() : 'Sin hora',
                        isPlaceholder: !_dueHasTime,
                        onTap: _openTime,
                      ),
                    ),
                    if (_dueHasTime) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _clearTime,
                        child: const Text('Quitar'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text('Recordatorio', style: textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  // ignore: deprecated_member_use
                  value: _reminderMinutesBefore,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Ninguno'),
                    ),
                    ...ReminderOffset.presets.map(
                      (preset) => DropdownMenuItem<int?>(
                        value: preset.minutesBefore,
                        child: Text(preset.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => _pickReminder(value),
                ),
              ],
            ),
          ),
          _buildFooter([
            FilledButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clear,
              child: const Text('Quitar fecha'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDatePage(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSheetHeader(
          title: 'Vencimiento',
          onBack: _backToForm,
        ),
        CalendarDatePicker(
          initialDate: _draftDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          currentDate: dateOnly(DateTime.now()),
          onDateChanged: (picked) {
            setState(() => _draftDate = dateOnly(picked));
          },
        ),
        _buildFooter([
          FilledButton(
            onPressed: _confirmDate,
            child: const Text('Listo'),
          ),
        ]),
      ],
    );
  }

  Widget _buildTimePage(BuildContext context) {
    final seed = DateTime(
      _dueAt.year,
      _dueAt.month,
      _dueAt.day,
      _draftTime.hour,
      _draftTime.minute,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSheetHeader(
          title: 'Hora',
          onBack: _backToForm,
        ),
        SizedBox(
          height: 216,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              primaryColor: Theme.of(context).colorScheme.primary,
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: seed,
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              onDateTimeChanged: (picked) {
                setState(() => _draftTime = TimeOfDay.fromDateTime(picked));
              },
            ),
          ),
        ),
        _buildFooter([
          FilledButton(
            onPressed: _confirmTime,
            child: const Text('Listo'),
          ),
        ]),
      ],
    );
  }
}
