import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/billing/domain/product_mapping.dart';

void main() {
  test('keeps entitlement and product identifiers centralized', () {
    expect(ProductMapping.entitlementId, 'wodo_plus');
    expect(ProductMapping.all, hasLength(2));
    expect(
      ProductMapping.monthly.nativeProductId(BillingPlatform.apple),
      'wodo_plus_monthly',
    );
    expect(
      ProductMapping.annual.nativeProductId(BillingPlatform.google),
      'wodo_plus:annual',
    );
    expect(
      ProductMapping.monthly.nativeProductId(BillingPlatform.web),
      r'$rc_monthly',
    );
  });
}
