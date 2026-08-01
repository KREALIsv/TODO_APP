import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _fileFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes.buffer.asUint8List());
}

String? _materialFontsDir() {
  final candidates = <String>[];

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    candidates.add('$flutterRoot/bin/cache/artifacts/material_fonts');
  }

  try {
    final which = Process.runSync('which', ['flutter']);
    if (which.exitCode == 0) {
      final flutterBin = which.stdout.toString().trim();
      if (flutterBin.isNotEmpty) {
        final sdkRoot = File(flutterBin).parent.parent.path;
        candidates.add('$sdkRoot/bin/cache/artifacts/material_fonts');
      }
    }
  } catch (_) {
    // `which` may be unavailable on some platforms; fall through to defaults.
  }

  candidates.add('/opt/flutter/bin/cache/artifacts/material_fonts');

  for (final path in candidates) {
    if (Directory(path).existsSync()) return path;
  }
  return null;
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
