import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../features/encryption/data/crypto_service.dart';
import 'secure_key_store.dart';

/// Device-local Hive encryption (at rest). Independent of the cloud E2EE DEK.
///
/// - Works without an account (local-first).
/// - Survives logout: LDEK is not cleared when the JWT/cloud DEK is.
/// - Optional app lock: PIN wraps the LDEK. The PIN is not the Hive key.
///   While lock is on, the raw LDEK is not kept on disk.
class LocalStorageService extends ChangeNotifier {
  LocalStorageService._();

  static final instance = LocalStorageService._();

  static const ldekStorageKey = 'wodo.local.ldek.v1';
  static const ldekWrapStorageKey = 'wodo.local.ldek.wrap.v1';
  static const ldekWrapSaltStorageKey = 'wodo.local.ldek.wrap.salt.v1';
  static const appLockEnabledStorageKey = 'wodo.local.applock.enabled.v1';

  /// User-content boxes encrypted at rest. Settings / device / sync stay plain
  /// so bootstrap and lock-state flags remain readable.
  static const encryptedBoxNames = <String>{
    'notes',
    'day_entries',
    'tags',
    'attachments',
    'attachment_blobs',
  };

  SecureKeyStore _store = FlutterSecureKeyStore();
  final CryptoService _crypto = CryptoService.instance;
  List<int>? _ldek;
  bool _initialized = false;
  bool _appLockEnabled = false;
  String? _failure;

  bool get isInitialized => _initialized;

  /// At-rest encryption is configured (LDEK in memory, or PIN wrap on disk).
  bool get isEnabled => _ldek != null || _appLockEnabled;
  bool get isAppLockEnabled => _appLockEnabled;
  bool get isSessionUnlocked => _ldek != null;
  bool get needsUnlock => _appLockEnabled && _ldek == null;
  String? get failureMessage => _failure;
  HiveCipher? get cipher =>
      _ldek == null ? null : HiveAesCipher(List<int>.from(_ldek!));

  /// Call once after [Hive.init] / [Hive.initFlutter], before content boxes.
  Future<void> init({SecureKeyStore? store}) async {
    if (store != null) _store = store;
    _failure = null;
    try {
      final wrap = await _store.read(ldekWrapStorageKey);
      final salt = await _store.read(ldekWrapSaltStorageKey);
      final hasWrap =
          wrap != null && wrap.isNotEmpty && salt != null && salt.isNotEmpty;
      // Wrap on disk is the source of truth (raw LDEK is deleted while locked).
      _appLockEnabled = hasWrap;

      if (_appLockEnabled) {
        // Never keep the raw LDEK on disk while the lock is on.
        await _store.delete(ldekStorageKey);
        _ldek = null;
      } else {
        final existing = await _store.read(ldekStorageKey);
        if (existing != null && existing.isNotEmpty) {
          _ldek = base64Decode(existing);
        } else {
          final generated = Hive.generateSecureKey();
          await _store.write(ldekStorageKey, base64Encode(generated));
          _ldek = generated;
        }
        if (_ldek == null || _ldek!.length != 32) {
          throw StateError('LDEK inválida');
        }
      }
    } catch (error) {
      _ldek = null;
      _appLockEnabled = false;
      _failure = '$error';
      debugPrint('Local Hive encryption unavailable: $error');
    }
    _initialized = true;
    notifyListeners();
  }

  bool encrypts(String boxName) =>
      isEnabled && encryptedBoxNames.contains(boxName);

  Future<Box<E>> openBox<E>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<E>(name);
    }
    return _openFresh<E>(name);
  }

  /// Close + reopen with the same cipher (web multi-tab reload).
  Future<Box<E>> reopenBox<E>(String name) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box(name).close();
    }
    return _openFresh<E>(name);
  }

  Future<Box<E>> _openFresh<E>(String name) async {
    if (!encrypts(name)) {
      return Hive.openBox<E>(name);
    }

    final encryptionCipher = cipher;
    if (encryptionCipher == null) {
      throw StateError(
        'La app está bloqueada. Desbloquea con tu PIN antes de abrir "$name".',
      );
    }

    try {
      // crashRecovery must be off while probing: a plaintext box fails the
      // key CRC, and Hive would otherwise truncate it into an empty vault.
      return await Hive.openBox<E>(
        name,
        encryptionCipher: encryptionCipher,
        crashRecovery: false,
      );
    } catch (encryptedError) {
      try {
        return await _migratePlaintextBox<E>(
          name,
          encryptionCipher: encryptionCipher,
        );
      } catch (plainError) {
        throw StateError(
          'No se pudo abrir la caja "$name" cifrada ni en claro. '
          'Cifrado: $encryptedError. Plano: $plainError',
        );
      }
    }
  }

  Future<Box<E>> _migratePlaintextBox<E>(
    String name, {
    required HiveCipher encryptionCipher,
  }) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box(name).close();
    }
    final plain = await Hive.openBox<E>(name, crashRecovery: false);
    final snapshot = Map<dynamic, dynamic>.from(plain.toMap());
    await plain.close();
    await Hive.deleteBoxFromDisk(name);
    final encrypted = await Hive.openBox<E>(
      name,
      encryptionCipher: encryptionCipher,
    );
    if (snapshot.isNotEmpty) {
      for (final entry in snapshot.entries) {
        await encrypted.put(entry.key, entry.value as E);
      }
    }
    return encrypted;
  }

  /// Wraps the in-memory LDEK with [pin] and removes the raw key from disk.
  Future<void> enableAppLock(String pin) async {
    if (_ldek == null || _ldek!.length != 32) {
      throw StateError('No hay clave local en memoria.');
    }
    final wrapped = await _crypto.wrapLdekForPin(ldek: _ldek!, pin: pin);
    await _store.write(ldekWrapStorageKey, wrapped.payload);
    await _store.write(ldekWrapSaltStorageKey, wrapped.salt);
    await _store.write(appLockEnabledStorageKey, '1');
    await _store.delete(ldekStorageKey);
    _appLockEnabled = true;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final unwrapped = await _unwrapLdek(pin);
    if (unwrapped == null) return false;
    _ldek = unwrapped;
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final unwrapped = await _unwrapLdek(pin);
    return unwrapped != null;
  }

  Future<bool> disableAppLock(String pin) async {
    final unwrapped = await _unwrapLdek(pin);
    if (unwrapped == null) return false;
    _ldek = unwrapped;
    await _store.write(ldekStorageKey, base64Encode(_ldek!));
    await _store.delete(ldekWrapStorageKey);
    await _store.delete(ldekWrapSaltStorageKey);
    await _store.delete(appLockEnabledStorageKey);
    _appLockEnabled = false;
    notifyListeners();
    return true;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final unwrapped = await _unwrapLdek(currentPin);
    if (unwrapped == null) return false;
    _ldek = unwrapped;
    await enableAppLock(newPin);
    return true;
  }

  /// Drops local encrypted notes after a forgotten PIN and starts a new LDEK.
  Future<void> resetAfterForgottenPin() async {
    for (final name in encryptedBoxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
      await Hive.deleteBoxFromDisk(name);
    }
    await _store.delete(ldekStorageKey);
    await _store.delete(ldekWrapStorageKey);
    await _store.delete(ldekWrapSaltStorageKey);
    await _store.delete(appLockEnabledStorageKey);
    _appLockEnabled = false;
    final generated = Hive.generateSecureKey();
    await _store.write(ldekStorageKey, base64Encode(generated));
    _ldek = generated;
    notifyListeners();
  }

  Future<List<int>?> _unwrapLdek(String pin) async {
    final payload = await _store.read(ldekWrapStorageKey);
    final salt = await _store.read(ldekWrapSaltStorageKey);
    if (payload == null || salt == null) return null;
    try {
      final ldek = await _crypto.unwrapLdekFromPin(
        pin: pin,
        saltBase64: salt,
        payload: payload,
      );
      if (ldek.length != 32) return null;
      return ldek;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  Future<void> debugReset() async {
    _ldek = null;
    _initialized = false;
    _failure = null;
    _appLockEnabled = false;
    _store = FlutterSecureKeyStore();
  }

  @visibleForTesting
  List<int>? get debugLdek => _ldek == null ? null : List<int>.from(_ldek!);
}
