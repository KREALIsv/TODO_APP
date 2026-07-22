import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> shareBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) async {
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
}
