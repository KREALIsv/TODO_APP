enum BillingPlatform { apple, google, web }

enum BillingPeriod { monthly, annual }

class ProductMapping {
  const ProductMapping({
    required this.period,
    required this.appleProductId,
    required this.googleProductId,
    required this.googleBasePlanId,
    required this.revenueCatPackageId,
  });

  static const entitlementId = 'wodo_plus';
  static const offeringId = 'default';

  final BillingPeriod period;
  final String appleProductId;
  final String googleProductId;
  final String googleBasePlanId;
  final String revenueCatPackageId;

  static const monthly = ProductMapping(
    period: BillingPeriod.monthly,
    appleProductId: 'wodo_plus_monthly',
    googleProductId: 'wodo_plus',
    googleBasePlanId: 'monthly',
    revenueCatPackageId: r'$rc_monthly',
  );

  static const annual = ProductMapping(
    period: BillingPeriod.annual,
    appleProductId: 'wodo_plus_annual',
    googleProductId: 'wodo_plus',
    googleBasePlanId: 'annual',
    revenueCatPackageId: r'$rc_annual',
  );

  static const all = [monthly, annual];

  String nativeProductId(BillingPlatform platform) {
    return switch (platform) {
      BillingPlatform.apple => appleProductId,
      BillingPlatform.google => '$googleProductId:$googleBasePlanId',
      BillingPlatform.web => revenueCatPackageId,
    };
  }
}
