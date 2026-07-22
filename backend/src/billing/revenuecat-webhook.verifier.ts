import { Injectable } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';

@Injectable()
export class RevenueCatWebhookVerifier {
  verify(params: {
    rawBody: Buffer;
    signatureHeader: string;
    signingSecret: string;
    nowSeconds?: number;
    toleranceSeconds?: number;
  }): boolean {
    const parts = this.parseSignature(params.signatureHeader);
    if (parts === null) return false;

    const now = params.nowSeconds ?? Math.floor(Date.now() / 1000);
    const tolerance = params.toleranceSeconds ?? 300;
    if (Math.abs(now - parts.timestamp) > tolerance) return false;

    const computed = createHmac('sha256', params.signingSecret)
      .update(`${parts.timestamp}.`)
      .update(params.rawBody)
      .digest('hex');
    const expectedBuffer = Buffer.from(parts.signature, 'utf8');
    const computedBuffer = Buffer.from(computed, 'utf8');
    return expectedBuffer.length === computedBuffer.length &&
      timingSafeEqual(expectedBuffer, computedBuffer);
  }

  safeEqual(actual: string, expected: string): boolean {
    const actualBuffer = Buffer.from(actual, 'utf8');
    const expectedBuffer = Buffer.from(expected, 'utf8');
    return actualBuffer.length === expectedBuffer.length &&
      timingSafeEqual(actualBuffer, expectedBuffer);
  }

  private parseSignature(
    header: string,
  ): { timestamp: number; signature: string } | null {
    const values = Object.fromEntries(
      header.split(',').map((part) => {
        const separator = part.indexOf('=');
        return separator < 1
          ? ['', '']
          : [part.slice(0, separator).trim(), part.slice(separator + 1).trim()];
      }),
    );
    const timestamp = Number(values.t);
    if (!Number.isInteger(timestamp) || !/^[a-f0-9]{64}$/i.test(values.v1 ?? '')) {
      return null;
    }
    return { timestamp, signature: values.v1 };
  }
}
