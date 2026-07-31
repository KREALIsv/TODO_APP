import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/sync/data/wodo_api_config.dart';

void main() {
  test('uses production API when compile-time URL is empty', () {
    expect(WodoApiConfig.baseUrl, 'https://api.wodo.app/api/v1');
    expect(WodoApiConfig.isConfigured, isTrue);
  });
}
