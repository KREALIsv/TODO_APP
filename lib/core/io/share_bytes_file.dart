import 'dart:typed_data';

import 'share_bytes_file_io.dart'
    if (dart.library.html) 'share_bytes_file_web.dart' as impl;

/// Shares [bytes] as a named file (web: in-memory XFile; native: temp file).
///
/// Used by backup export and attachment download so presentation/data
/// layers do not reimplement the web/native split.
Future<void> shareBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) {
  return impl.shareBytesAsFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    subject: subject,
  );
}
