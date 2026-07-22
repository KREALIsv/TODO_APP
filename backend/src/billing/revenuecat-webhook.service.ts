import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../common/services';

@Injectable()
export class RevenueCatWebhookService {
  constructor(private readonly prisma: PrismaService) {}

  async processEvent(payload: Record<string, unknown>): Promise<void> {
    const eventId = payload.event_id as string | undefined;
    const eventType = (payload.event as Record<string, unknown> | undefined)
      ?.event_type as string | undefined;

    if (!eventId || !eventType) {
      throw new Error('Missing event_id or event_type');
    }

    const appUserId = (payload.event as Record<string, unknown>)
      ?.app_user_id as string | undefined;

    // Idempotency: skip if already processed.
    const existing = await this.prisma.billingEvent.findUnique({
      where: { eventId },
    });

    if (existing) {
      return;
    }

    await this.prisma.billingEvent.create({
      data: {
        eventId,
        eventType,
        appUserId: appUserId ?? '',
        store: (payload.event as Record<string, unknown>)?.store as string | null,
        productId: (payload.event as Record<string, unknown>)
          ?.product_id as string | null,
        status: (payload.event as Record<string, unknown>)?.period_type as string | null,
        rawPayload: payload as Prisma.InputJsonValue,
      },
    });

    // TODO: reconcile Subscription / Entitlement when Release 3 billing lands.
  }
}
