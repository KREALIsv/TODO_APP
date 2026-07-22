import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install identity used to register this client with the API.
class DeviceIdentity extends ChangeNotifier {
  DeviceIdentity._();

  static final instance = DeviceIdentity._();

  static const _boxName = 'device_identity';
  static const _appUserIdKey = 'app_user_id';
  static const _syncEnabledKey = 'sync_enabled';
  static const _uuid = Uuid();

  late Box<dynamic> _box;
  String? _appUserId;
  bool _syncEnabled = true;
  String _platformLabel = 'Desconocido';

  String get appUserId {
    final id = _appUserId;
    if (id == null) {
      throw StateError('DeviceIdentity is not initialized');
    }
    return id;
  }

  bool get syncEnabled => _syncEnabled;
  String get platformLabel => _platformLabel;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _appUserId = _box.get(_appUserIdKey) as String?;
    _appUserId ??= _uuid.v4();
    await _box.put(_appUserIdKey, _appUserId);
    _syncEnabled = (_box.get(_syncEnabledKey) as bool?) ?? true;
    _platformLabel = await _resolvePlatformLabel();
  }

  Future<void> setSyncEnabled(bool enabled) async {
    _syncEnabled = enabled;
    await _box.put(_syncEnabledKey, enabled);
    notifyListeners();
  }

  Future<String> _resolvePlatformLabel() async {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  Future<String> appVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }
}
