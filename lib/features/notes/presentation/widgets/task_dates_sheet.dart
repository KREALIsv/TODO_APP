import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';
import '../../data/task_reminders_service.dart';
import '../../domain/date_only.dart';
import '../../domain/reminder_offset.dart';

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOnly(_dueAt),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      useRootNavigator: true,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueAt = _dueHasTime
          ? DateTime(
              picked.year,
              picked.month,
              picked.day,
              _dueAt.hour,
              _dueAt.minute,
            )
          : DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueHasTime
          ? TimeOfDay.fromDateTime(_dueAt)
          : TimeOfDay.fromDateTime(DateTime.now()),
      useRootNavigator: true,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueHasTime = true;
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        picked.hour,
        picked.minute,
      );
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
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'Fecha',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Vencimiento', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              _EditableValueField(
                value: _formatDate(),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              Text('Hora', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _EditableValueField(
                      value: _dueHasTime ? _formatTime() : 'Sin hora',
                      isPlaceholder: !_dueHasTime,
                      onTap: _pickTime,
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('Guardar'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _clear,
                child: const Text('Quitar fecha'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableValueField extends StatelessWidget {
  const _EditableValueField({
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
  });

  final String value;
  final VoidCallback onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: ThemeTokens.borderRadius,
        side: BorderSide(color: AppColors.neutral20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: ThemeTokens.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isPlaceholder
                        ? AppColors.neutral40
                        : AppColors.neutral100,
                  ),
                ),
              ),
              const Icon(
                Icons.expand_more,
                size: 22,
                color: AppColors.neutral60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
