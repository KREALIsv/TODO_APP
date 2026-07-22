import {
  Controller,
  Headers,
  HttpCode,
  Post,
  RawBodyRequest,
  Req,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';

import { RevenueCatWebhookService } from './revenuecat-webhook.service';
import { RevenueCatWebhookVerifier } from './revenuecat-webhook.verifier';

@Controller('webhooks/revenuecat')
export class RevenueCatWebhookController {
  constructor(
    private readonly config: ConfigService,
    private readonly verifier: RevenueCatWebhookVerifier,
    private readonly service: RevenueCatWebhookService,
  ) {}

  @Post()
  @HttpCode(200)
  async receive(
    @Req() request: RawBodyRequest<Request>,
    @Headers('authorization') authorization = '',
    @Headers('x-revenuecat-webhook-signature') signature = '',
  ): Promise<{ received: true; duplicate: boolean }> {
    const expectedAuthorization = this.config.get<string>(
      'REVENUECAT_WEBHOOK_AUTHORIZATION',
    );
    const signingSecret = this.config.get<string>(
      'REVENUECAT_WEBHOOK_SIGNING_SECRET',
    );
    if (!expectedAuthorization || !signingSecret) {
      throw new ServiceUnavailableException('Webhook secrets are not configured');
    }
    if (!this.verifier.safeEqual(authorization, expectedAuthorization)) {
      throw new UnauthorizedException('Invalid authorization');
    }

    const rawBody = request.rawBody;
    if (
      !rawBody ||
      !this.verifier.verify({ rawBody, signatureHeader: signature, signingSecret })
    ) {
      throw new UnauthorizedException('Invalid signature');
    }

    const payload = request.body as Record<string, unknown>;
    const eventId = (payload.event as Record<string, unknown> | undefined)
      ?.id as string | undefined;

    // Persist event with idempotency.
    await this.service.processEvent(payload);

    return { received: true, duplicate: eventId == null };
  }
}
