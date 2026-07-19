import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/notes_repository.dart';
import '../../domain/note_item.dart';

/// Schedules UI ticks when due times cross, so overdue badges update live.
class ClockRefreshController {
  ClockRefreshController({
    required this.repository,
    required this.onTick,
  });

  final NotesRepository repository;
  final VoidCallback onTick;

  Timer? _timer;
  final _lifecycle = _LifecycleBinder();

  void start() {
    _lifecycle.bind(this);
    schedule();
  }

  void dispose() {
    _lifecycle.unbind();
    _timer?.cancel();
  }

  void onAppResumed() {
    onTick();
    schedule();
  }

  void schedule() {
    _timer?.cancel();

    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));

    var delay = nextMinute.difference(now);

    for (final item in repository.getAll()) {
      if (item.type != NoteType.task || item.completed || item.dueAt == null) {
        continue;
      }
      if (!item.dueHasTime) continue;
      if (!item.dueAt!.isAfter(now)) continue;
      final untilDue = item.dueAt!.difference(now);
      if (untilDue < delay) delay = untilDue;
    }

    if (delay < const Duration(milliseconds: 500)) {
      delay = const Duration(seconds: 1);
    }

    _timer = Timer(delay + const Duration(milliseconds: 250), () {
      onTick();
      schedule();
    });
  }
}

class _LifecycleBinder with WidgetsBindingObserver {
  ClockRefreshController? _controller;

  void bind(ClockRefreshController controller) {
    _controller = controller;
    WidgetsBinding.instance.addObserver(this);
  }

  void unbind() {
    WidgetsBinding.instance.removeObserver(this);
    _controller = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.onAppResumed();
    }
  }
}
