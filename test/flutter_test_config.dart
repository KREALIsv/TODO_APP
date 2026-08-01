import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _fileFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes.buffer.asUint8List());
}

String? _flutterSdkRoot() {
  try {
    final result = Process.runSync('flutter', ['--version', '--machine']);
    if (result.exitCode == 0) {
      final stdout = result.stdout.toString().trim();
      if (stdout.isNotEmpty) {
        final json = jsonDecode(stdout) as Map<String, dynamic>;
        final root = json['flutterRoot']?.toString();
        if (root != null && root.isNotEmpty) return root;
      }
    }
  } catch (_) {
    // Fall through to env / PATH resolution.
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    return flutterRoot;
  }

  try {
    final which = Process.runSync('which', ['flutter']);
    if (which.exitCode == 0) {
      final flutterBin = which.stdout.toString().trim();
      if (flutterBin.isNotEmpty) {
        return File(flutterBin).parent.parent.path;
      }
    }
  } catch (_) {
    // Ignore; fonts are optional for tests.
  }

  return null;
}

String? _materialFontsDir() {
  final sdkRoot = _flutterSdkRoot();
  if (sdkRoot == null) return null;

  final fontRoot = '$sdkRoot/bin/cache/artifacts/material_fonts';
  return Directory(fontRoot).existsSync() ? fontRoot : null;
}

Future<void> _loadTestFonts() async {
  final fontRoot = _materialFontsDir();
  if (fontRoot == null) return;

  final roboto = FontLoader('Roboto')
    ..addFont(_fileFont('$fontRoot/Roboto-Regular.ttf'))
    ..addFont(_fileFont('$fontRoot/Roboto-Medium.ttf'))
    ..addFont(_fileFont('$fontRoot/Roboto-Bold.ttf'));
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(_fileFont('$fontRoot/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadTestFonts();
  await testMain();
}
