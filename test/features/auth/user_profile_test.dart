import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/auth/domain/user_profile.dart';

void main() {
  test('UserProfile parses API payload', () {
    final profile = UserProfile.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'email': 'maria@example.com',
      'createdAt': '2026-01-15T10:30:00.000Z',
    });

    expect(profile.email, 'maria@example.com');
    expect(profile.id, '11111111-1111-1111-1111-111111111111');
    expect(profile.createdAt.toUtc().year, 2026);
  });
}
