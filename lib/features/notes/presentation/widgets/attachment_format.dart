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

/// Cover height for a card-width image preview.
///
/// The card width is fixed by the list/grid layout, so the cover follows the
/// image aspect ratio and clamps only to keep very wide/tall images usable.
/// Portrait covers may grow up to [maxHeight] (default allows ~4:5 on phone).
double attachmentCoverHeight({
  required double cardWidth,
  int? imageWidth,
  int? imageHeight,
  double fallbackHeight = 128,
  double minHeight = 96,
  double maxHeight = 520,
}) {
  if (cardWidth <= 0 ||
      imageWidth == null ||
      imageHeight == null ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    return fallbackHeight;
  }

  final aspect = imageWidth / imageHeight;
  final height = cardWidth / aspect;
  return height.clamp(minHeight, maxHeight).toDouble();
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
