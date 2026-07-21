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
