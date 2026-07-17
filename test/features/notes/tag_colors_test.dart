import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/tag_colors.dart';
import 'package:todos_app/global/themes/app_colors.dart';

void main() {
  group('TagColors.colorForTag', () {
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
      final foregrounds = TagColors.palette.map((p) => p.foreground).toSet();
      expect(backgrounds.contains(pair.background), isTrue);
      expect(foregrounds.contains(pair.foreground), isTrue);
    });

    test('palette has six soft color pairs', () {
      expect(TagColors.palette, hasLength(6));
      expect(TagColors.palette.first.background, AppColors.primary00);
    });
  });
}
