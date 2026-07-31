import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _fileFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fontRoot = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto')
    ..addFont(_fileFont('$fontRoot/Roboto-Regular.ttf'))
    ..addFont(_fileFont('$fontRoot/Roboto-Medium.ttf'))
    ..addFont(_fileFont('$fontRoot/Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(_fileFont('$fontRoot/MaterialIcons-Regular.otf'));
  await icons.load();
  await testMain();
}
