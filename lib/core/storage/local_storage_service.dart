import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import 'secure_key_store.dart';

/// Device-local Hive encryption (at rest). Independent of the cloud E2EE DEK.
///
/// - Works without an account (local-first).
/// - Survives logout: LDEK is not cleared when the JWT/cloud DEK is.
/// - PIN / biometrics can wrap this LDEK later; they are not the Hive key.
class LocalStorageService extends ChangeNotifier {
  LocalStorageService._();

  static final instance = LocalStorageService._();

  static const ldekStorageKey = 'wodo.local.ldek.v1';

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
  List<int>? _ldek;
  bool _initialized = false;
  String? _failure;

  bool get isInitialized => _initialized;
  bool get isEnabled => _ldek != null;
  String? get failureMessage => _failure;
  HiveCipher? get cipher =>
      _ldek == null ? null : HiveAesCipher(List<int>.from(_ldek!));

  /// Call once after [Hive.init] / [Hive.initFlutter], before content boxes.
  Future<void> init({SecureKeyStore? store}) async {
    if (store != null) _store = store;
    _failure = null;
    try {
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
    } catch (error) {
      _ldek = null;
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

    final encryptionCipher = cipher!;
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

  @visibleForTesting
  Future<void> debugReset() async {
    _ldek = null;
    _initialized = false;
    _failure = null;
    _store = FlutterSecureKeyStore();
  }

  @visibleForTesting
  List<int>? get debugLdek => _ldek == null ? null : List<int>.from(_ldek!);
}
