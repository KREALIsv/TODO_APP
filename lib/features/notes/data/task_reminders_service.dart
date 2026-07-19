import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/note_item.dart';
import '../domain/reminder_offset.dart';

/// Local reminders over [NoteItem.dueAt] (PRD §6.12).
class TaskRemindersService {
  TaskRemindersService._();

  static final TaskRemindersService instance = TaskRemindersService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionAsked = false;
  bool _unavailable = false;

  /// Flip off in unit tests (plugin platform is not registered).
  @visibleForTesting
  static bool enabled = true;

  static const _channelId = 'task_reminders';
  static const _channelName = 'Recordatorios de tareas';
  static const _channelDescription =
      'Avisos locales antes o en la fecha de vencimiento';

  bool get isSupported {
    if (!enabled || _unavailable || kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  void _markUnavailable(Object error, StackTrace stackTrace) {
    _unavailable = true;
    _initialized = false;
    debugPrint(
      'TaskRemindersService disabled (plugin unavailable): $error\n'
      'If you just added the package, stop the app and run a full '
      '`flutter run` (hot reload/restart is not enough).\n$stackTrace',
    );
  }

  Future<void> init() async {
    if (_initialized || !isSupported) return;

    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Keep UTC if detection fails; scheduling still works relative to UTC.
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } on MissingPluginException catch (e, st) {
      _markUnavailable(e, st);
    } catch (e, st) {
      _markUnavailable(e, st);
    }
  }

  /// Requests OS permission the first time the user enables a reminder.
  Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    await init();
    if (!isSupported || !_initialized) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        _permissionAsked = true;
        return granted ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionAsked = true;
        return granted ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mac = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final granted = await mac?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionAsked = true;
        return granted ?? false;
      }
    } on MissingPluginException catch (e, st) {
      _markUnavailable(e, st);
      return false;
    }

    return false;
  }

  bool get permissionAsked => _permissionAsked;

  int notificationIdFor(String noteId) => noteId.hashCode & 0x7FFFFFFF;

  Future<void> cancel(String noteId) async {
    if (!isSupported) return;
    await init();
    if (!isSupported || !_initialized) return;
    try {
      await _plugin.cancel(notificationIdFor(noteId));
    } on MissingPluginException catch (e, st) {
      _markUnavailable(e, st);
    }
  }

  /// Cancel + schedule (or just cancel) according to current item state.
  Future<void> sync(NoteItem item) async {
    if (!isSupported) return;
    await init();
    if (!isSupported || !_initialized) return;

    try {
      await _plugin.cancel(notificationIdFor(item.id));

      final fire = ReminderOffset.fireAt(item);
      if (fire == null) return;

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final scheduled = tz.TZDateTime.from(fire, tz.local);
      await _plugin.zonedSchedule(
        notificationIdFor(item.id),
        'Recordatorio',
        item.displayTitle,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.id,
      );
    } on MissingPluginException catch (e, st) {
      _markUnavailable(e, st);
    }
  }

  Future<void> syncAll(Iterable<NoteItem> items) async {
    if (!isSupported) return;
    await init();
    if (!isSupported || !_initialized) return;
    for (final item in items) {
      await sync(item);
      if (!isSupported) return;
    }
  }

  /// Best-effort; used when platform APIs are unavailable (tests / web).
  @visibleForTesting
  void markInitializedForTests() {
    _initialized = true;
  }
}
