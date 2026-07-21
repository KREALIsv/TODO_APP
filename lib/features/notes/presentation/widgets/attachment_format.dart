/// Absolute local date+time for attachment metadata (`21/07/2026 · 15:18`).
String formatAttachmentAddedAt(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

String formatAttachmentByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    final text = kb < 10 ? kb.toStringAsFixed(1) : kb.toStringAsFixed(0);
    return '$text KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Strip thumb size: fixed [height], width follows image aspect (clamped).
///
/// Portrait images (`width < height`) get a narrower frame so the content
/// is not crushed inside a square.
({double width, double height}) attachmentStripThumbSize({
  int? imageWidth,
  int? imageHeight,
  double height = 64,
  double minWidth = 44,
  double maxWidth = 88,
}) {
  if (imageWidth == null ||
      imageHeight == null ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    return (width: height, height: height);
  }
  final aspect = imageWidth / imageHeight;
  final width = (height * aspect).clamp(minWidth, maxWidth);
  return (width: width.toDouble(), height: height);
}
