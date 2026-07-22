import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { BillingController } from './billing.controller';
import { BillingService } from './billing.service';
import { RevenueCatWebhookController } from './revenuecat-webhook.controller';
import { RevenueCatWebhookService } from './revenuecat-webhook.service';
import { RevenueCatWebhookVerifier } from './revenuecat-webhook.verifier';

@Module({
  controllers: [BillingController, RevenueCatWebhookController],
  providers: [
    BillingService,
    RevenueCatWebhookService,
    RevenueCatWebhookVerifier,
    PrismaService,
  ],
})
export class BillingModule {}
