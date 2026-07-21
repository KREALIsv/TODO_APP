import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/presentation/widgets/attachments_editor.dart';

void main() {
  test('formatAttachmentByteSize', () {
    expect(formatAttachmentByteSize(512), '512 B');
    expect(formatAttachmentByteSize(1536), '1.5 KB');
    expect(formatAttachmentByteSize(20 * 1024), '20 KB');
    expect(formatAttachmentByteSize(2 * 1024 * 1024), '2.0 MB');
  });

  test('formatAttachmentAddedAt uses local date and time', () {
    final value = DateTime(2026, 7, 21, 15, 8);
    expect(formatAttachmentAddedAt(value), '21/07/2026 · 15:08');
  });
}
