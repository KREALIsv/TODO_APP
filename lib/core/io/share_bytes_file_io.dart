import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) async {
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
