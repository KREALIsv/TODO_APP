import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/sync/domain/account_switch_gate.dart';

void main() {
  group('detectAccountSwitchPrompt', () {
    test('returns null for first login without bound account', () {
      expect(
        detectAccountSwitchPrompt(
          boundAccountEmail: null,
          currentEmail: 'user@example.com',
          hasLocalContent: true,
        ),
        isNull,
      );
    });

    test('returns null when emails match', () {
      expect(
        detectAccountSwitchPrompt(
          boundAccountEmail: 'user@example.com',
          currentEmail: 'user@example.com',
          hasLocalContent: true,
        ),
        isNull,
      );
    });

    test('returns null when local device has no account-specific content', () {
      expect(
        detectAccountSwitchPrompt(
          boundAccountEmail: 'a@example.com',
          currentEmail: 'b@example.com',
          hasLocalContent: false,
        ),
        isNull,
      );
    });

    test('returns prompt when account changes and local content exists', () {
      final prompt = detectAccountSwitchPrompt(
        boundAccountEmail: 'a@example.com',
        currentEmail: 'b@example.com',
        hasLocalContent: true,
      );

      expect(prompt, isNotNull);
      expect(prompt!.fromEmail, 'a@example.com');
      expect(prompt.toEmail, 'b@example.com');
    });

    test('matches emails case-insensitively', () {
      expect(
        detectAccountSwitchPrompt(
          boundAccountEmail: 'User@Example.com',
          currentEmail: 'user@example.com',
          hasLocalContent: true,
        ),
        isNull,
      );
    });
  });
}
