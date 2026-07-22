import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

class AppIdentityRepository extends ChangeNotifier {
  AppIdentityRepository._();

  static final instance = AppIdentityRepository._();
  static const _boxName = 'platform_identity';
  static const _appUserIdKey = 'app_user_id';

  Box<dynamic>? _box;
  String? _appUserId;

  String get appUserId {
    final value = _appUserId;
    if (value == null) {
      throw StateError('AppIdentityRepository is not initialized');
    }
    return value;
  }

  Future<void> init({String? overrideAppUserId}) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await initWithBox(box, overrideAppUserId: overrideAppUserId);
  }

  @visibleForTesting
  Future<void> initWithBox(
    Box<dynamic> box, {
    String? overrideAppUserId,
  }) async {
    _box = box;
    final override = overrideAppUserId?.trim();
    if (override != null && override.isNotEmpty) {
      if (!Uuid.isValidUUID(fromString: override)) {
        throw ArgumentError.value(
          overrideAppUserId,
          'overrideAppUserId',
          'Must be a valid UUID',
        );
      }
      _appUserId = override;
      notifyListeners();
      return;
    }

    final stored = box.get(_appUserIdKey);
    if (stored is String && Uuid.isValidUUID(fromString: stored)) {
      _appUserId = stored;
    } else {
      _appUserId = const Uuid().v4();
      await box.put(_appUserIdKey, _appUserId);
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box?.clear();
    _appUserId = null;
    notifyListeners();
  }
}
