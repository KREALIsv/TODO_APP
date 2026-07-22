import { createHmac } from 'node:crypto';

import { RevenueCatWebhookVerifier } from '../src/billing/revenuecat-webhook.verifier';

const verifier = new RevenueCatWebhookVerifier();
const rawBody = Buffer.from('{"event":{"id":"evt_1"}}');
const secret = 'sandbox-signing-secret';
const timestamp = 1_750_000_000;
const signature = createHmac('sha256', secret)
  .update(`${timestamp}.`)
  .update(rawBody)
  .digest('hex');

describe('RevenueCatWebhookVerifier', () => {
  it('accepts an authentic and recent RevenueCat payload', () => {
    expect(
      verifier.verify({
        rawBody,
        signatureHeader: `t=${timestamp},v1=${signature}`,
        signingSecret: secret,
        nowSeconds: timestamp + 60,
      }),
    ).toBe(true);
  });

  it('rejects tampering and replayed payloads', () => {
    expect(
      verifier.verify({
        rawBody: Buffer.from('{"event":{"id":"tampered"}}'),
        signatureHeader: `t=${timestamp},v1=${signature}`,
        signingSecret: secret,
        nowSeconds: timestamp,
      }),
    ).toBe(false);

    expect(
      verifier.verify({
        rawBody,
        signatureHeader: `t=${timestamp},v1=${signature}`,
        signingSecret: secret,
        nowSeconds: timestamp + 301,
      }),
    ).toBe(false);
  });
});
