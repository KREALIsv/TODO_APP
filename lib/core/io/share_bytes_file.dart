import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shares [bytes] as a named file (web: in-memory XFile; native: temp file).
///
/// Used by backup export and attachment download so presentation/data
/// layers do not reimplement the web/native split.
Future<void> shareBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) async {
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: mimeType,
          ),
        ],
        subject: subject ?? fileName,
      ),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          name: fileName,
          mimeType: mimeType,
        ),
      ],
      subject: subject ?? fileName,
    ),
  );
}
