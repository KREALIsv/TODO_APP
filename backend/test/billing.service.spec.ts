import { BillingService } from '../src/billing/billing.service';

describe('BillingService', () => {
  const prisma = {
    entitlement: { findUnique: jest.fn() },
    subscription: { findUnique: jest.fn() },
  };
  const config = { get: jest.fn() };
  const service = new BillingService(prisma as never, config as never);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('publishes the approved catalog', () => {
    expect(service.getPlans()).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'wodo_plus_monthly', price: 3.99 }),
        expect.objectContaining({ id: 'wodo_plus_annual', price: 29.99 }),
      ]),
    );
  });

  it('does not simulate a checkout before Polar is configured', () => {
    config.get.mockReturnValue(undefined);

    expect(
      service.createCheckoutIntent('user-1', 'wodo_plus_annual'),
    ).toEqual(
      expect.objectContaining({
        status: 'not_configured',
        checkoutUrl: null,
        provider: 'polar',
      }),
    );
  });

  it('treats an expired entitlement as free', async () => {
    prisma.entitlement.findUnique.mockResolvedValue({
      isActive: true,
      expiresAt: new Date('2020-01-01'),
    });
    prisma.subscription.findUnique.mockResolvedValue({
      status: 'expired',
      planId: 'wodo_plus_annual',
      provider: 'polar',
    });

    await expect(service.getAccountPlan('user-1')).resolves.toEqual(
      expect.objectContaining({ tier: 'free', status: 'expired' }),
    );
  });
});
