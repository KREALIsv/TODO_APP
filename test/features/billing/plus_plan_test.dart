import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/billing/domain/plus_plan.dart';

void main() {
  test('exposes the approved monthly and annual commercial offer', () {
    expect(PlusPlan.all, hasLength(2));
    expect(PlusPlan.monthly.id, 'wodo_plus_monthly');
    expect(PlusPlan.monthly.price, r'$3.99');
    expect(PlusPlan.annual.id, 'wodo_plus_annual');
    expect(PlusPlan.annual.price, r'$29.99');
    expect(PlusPlan.annual.badge, 'Ahorra 37%');
  });
}
