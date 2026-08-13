import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { AuthService } from './auth.service';
import { PrismaService } from '../common/services';
import { MailService } from '../mail';

describe('AuthService refresh token hashing', () => {
  const prisma = {
    session: {
      findUnique: jest.fn(),
      create: jest.fn(),
      delete: jest.fn(),
    },
  } as unknown as PrismaService;

  const mail = {
    isConfigured: jest.fn(() => false),
  } as unknown as MailService;

  const config = {
    getOrThrow: jest.fn((key: string) => {
      if (key === 'SECRET_AUTH_TOKEN_KEY') return 'test-secret-key-min-32-chars!!';
      if (key === 'ACCESS_TOKEN_EXPIRATION') return '15m';
      if (key === 'REFRESH_TOKEN_EXPIRATION') return '7d';
      throw new Error(`missing ${key}`);
    }),
    get: jest.fn((key: string, fallback?: unknown) => {
      if (key === 'ACCESS_TOKEN_EXPIRATION_WEB') return '24h';
      return fallback;
    }),
  } as unknown as ConfigService;

  let service: AuthService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new AuthService(config, prisma, mail);
    (prisma.session.create as jest.Mock).mockResolvedValue({});
  });

  it('stores sha256(refreshToken) instead of plaintext', async () => {
    const tokens = await service.issueSession('user-1', 'web');
    expect(tokens.refreshToken).toBeTruthy();

    const expectedHash = crypto
      .createHash('sha256')
      .update(tokens.refreshToken)
      .digest('hex');

    expect(prisma.session.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'user-1',
        refreshTokenHash: expectedHash,
      }),
    });
    const stored = (prisma.session.create as jest.Mock).mock.calls[0][0].data
      .refreshTokenHash as string;
    expect(stored).not.toEqual(tokens.refreshToken);
  });

  it('looks up sessions by hashed refresh token', async () => {
    const raw = 'raw-refresh-token';
    const hash = crypto.createHash('sha256').update(raw).digest('hex');
    (prisma.session.findUnique as jest.Mock).mockResolvedValue({
      id: 's1',
      userId: 'user-1',
      expiresAt: new Date(Date.now() + 60_000),
    });
    (prisma.session.delete as jest.Mock).mockResolvedValue({});

    await service.refresh(raw, 'web');

    expect(prisma.session.findUnique).toHaveBeenCalledWith({
      where: { refreshTokenHash: hash },
    });
  });

  it('rejects unknown refresh tokens', async () => {
    (prisma.session.findUnique as jest.Mock).mockResolvedValue(null);
    await expect(service.refresh('missing')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
