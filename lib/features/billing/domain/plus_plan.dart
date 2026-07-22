enum PlusPlanPeriod { monthly, annual }

class PlusPlan {
  const PlusPlan({
    required this.id,
    required this.period,
    required this.title,
    required this.price,
    required this.priceDetail,
    this.badge,
  });

  final String id;
  final PlusPlanPeriod period;
  final String title;
  final String price;
  final String priceDetail;
  final String? badge;

  static const monthly = PlusPlan(
    id: 'wodo_plus_monthly',
    period: PlusPlanPeriod.monthly,
    title: 'Mensual',
    price: r'$3.99',
    priceDetail: 'al mes',
  );

  static const annual = PlusPlan(
    id: 'wodo_plus_annual',
    period: PlusPlanPeriod.annual,
    title: 'Anual',
    price: r'$29.99',
    priceDetail: r'al año · $2.50/mes',
    badge: 'Ahorra 37%',
  );

  static const all = [monthly, annual];
}
