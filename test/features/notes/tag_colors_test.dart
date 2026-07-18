import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/tag_colors.dart';

void main() {
  group('TagColors', () {
    test('returns consistent color for the same tag', () {
      final a = TagColors.colorForTag('Work');
      final b = TagColors.colorForTag('Work');
      expect(a.background, b.background);
      expect(a.foreground, b.foreground);
    });

    test('is case-insensitive for hashing', () {
      final lower = TagColors.colorForTag('personal');
      final upper = TagColors.colorForTag('PERSONAL');
      expect(lower.background, upper.background);
      expect(lower.foreground, upper.foreground);
    });

    test('returns a pair from the fixed palette', () {
      final pair = TagColors.colorForTag('Meeting');
      final backgrounds = TagColors.palette.map((p) => p.background).toSet();
      expect(backgrounds.contains(pair.background), isTrue);
    });

    test('palette includes brand pink from favicon', () {
      expect(TagColors.brandPink, const Color(0xFFF2327D));
      expect(TagColors.swatches.first.id, 'brand_pink');
      expect(TagColors.swatches.first.color, TagColors.brandPink);
      expect(TagColors.swatches.length, greaterThanOrEqualTo(24));
    });

    test('byId resolves persisted swatch ids', () {
      final swatch = TagColors.byId('brand_pink');
      expect(swatch, isNotNull);
      expect(swatch!.color, TagColors.brandPink);
      expect(TagColors.byId('missing'), isNull);
    });

    test('defaultIdForTag is stable', () {
      expect(
        TagColors.defaultIdForTag('Urgente'),
        TagColors.defaultIdForTag('urgente'),
      );
    });
  });
}
