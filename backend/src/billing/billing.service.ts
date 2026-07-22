import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../common/services';

const plans = [
  {
    id: 'wodo_plus_monthly',
    title: 'Mensual',
    price: 3.99,
    currency: 'USD',
    interval: 'month',
    trialDays: 14,
  },
  {
    id: 'wodo_plus_annual',
    title: 'Anual',
    price: 29.99,
    currency: 'USD',
    interval: 'year',
    trialDays: 14,
  },
] as const;

@Injectable()
export class BillingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  getPlans() {
    return plans;
  }

  async getAccountPlan(userId: string) {
    const [entitlement, subscription] = await Promise.all([
      this.prisma.entitlement.findUnique({
        where: {
          userId_entitlementId: { userId, entitlementId: 'wodo_plus' },
        },
      }),
      this.prisma.subscription.findUnique({ where: { userId } }),
    ]);

    const active =
      entitlement?.isActive === true &&
      (!entitlement.expiresAt || entitlement.expiresAt > new Date());

    return {
      tier: active ? 'plus' : 'free',
      entitlement: 'wodo_plus',
      status: subscription?.status ?? 'inactive',
      planId: subscription?.planId ?? subscription?.productId ?? null,
      provider: subscription?.provider ?? null,
      expiresAt: subscription?.expiresAt ?? null,
      cancelAtPeriodEnd: subscription?.cancelAtPeriodEnd ?? false,
      manageUrl: null,
    };
  }

  createCheckoutIntent(userId: string, planId: string) {
    const plan = plans.find((candidate) => candidate.id === planId);
    if (!plan) {
      return { status: 'invalid_plan', checkoutUrl: null };
    }

    // Contract intentionally exists before the Polar SDK/API is connected.
    // Later this method will create a Polar checkout using userId as metadata.
    const configured = Boolean(this.config.get<string>('POLAR_ACCESS_TOKEN'));
    return {
      status: configured ? 'provider_pending' : 'not_configured',
      checkoutUrl: null,
      provider: 'polar',
      planId: plan.id,
      userId,
    };
  }

  restore(userId: string) {
    // Polar web purchases are reconciled by account + webhook. This endpoint is
    // shared with future native-store restoration and keeps the Flutter flow stable.
    return {
      status: 'not_configured',
      provider: 'polar',
      userId,
    };
  }
}
