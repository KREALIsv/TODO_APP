import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/presentation/widgets/attachment_format.dart';

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

  test('attachmentCoverHeight follows image aspect inside card bounds', () {
    expect(
      attachmentCoverHeight(cardWidth: 240, imageWidth: 120, imageHeight: 60),
      120,
    );
    // Portrait: natural height 480, default max 520 — no longer clamped to 320.
    expect(
      attachmentCoverHeight(cardWidth: 240, imageWidth: 100, imageHeight: 200),
      480,
    );
    expect(
      attachmentCoverHeight(
        cardWidth: 240,
        imageWidth: 100,
        imageHeight: 200,
        maxHeight: 320,
      ),
      320,
    );
    expect(
      attachmentCoverHeight(cardWidth: 240, imageWidth: 1200, imageHeight: 100),
      96,
    );
    expect(
      attachmentCoverHeight(
        cardWidth: 240,
        imageWidth: null,
        imageHeight: null,
      ),
      128,
    );
    expect(
      attachmentCoverHeight(cardWidth: 240, imageWidth: 0, imageHeight: 0),
      128,
    );
  });

  test('attachmentStripThumbSize narrows portrait frames', () {
    final portrait = attachmentStripThumbSize(
      imageWidth: 40,
      imageHeight: 80,
      height: 64,
    );
    expect(portrait.height, 64);
    expect(portrait.width, lessThan(64));
    expect(portrait.width, 44); // clamped to minWidth for 0.5 aspect

    final landscape = attachmentStripThumbSize(
      imageWidth: 160,
      imageHeight: 80,
      height: 64,
    );
    expect(landscape.width, 88); // clamped to maxWidth

    final square = attachmentStripThumbSize(
      imageWidth: 80,
      imageHeight: 80,
      height: 64,
    );
    expect(square.width, 64);
  });
}
