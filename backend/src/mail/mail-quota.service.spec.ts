import { HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MailQuotaService } from './mail-quota.service';
import { PrismaService } from '../common/services';

describe('MailQuotaService', () => {
  const prisma = {
    mailSendLog: {
      count: jest.fn(),
      create: jest.fn(),
    },
  } as unknown as PrismaService;

  const config = {
    get: jest.fn((key: string, fallback?: unknown) => {
      if (key === 'MAIL_MAX_PER_USER_FLOW') return 2;
      if (key === 'MAIL_FLOW_WINDOW_HOURS') return 24;
      return fallback;
    }),
  } as unknown as ConfigService;

  let service: MailQuotaService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new MailQuotaService(config, prisma);
  });

  it('allows send when under quota', async () => {
    (prisma.mailSendLog.count as jest.Mock).mockResolvedValue(1);

    await expect(
      service.assertCanSend('user@example.com', 'password_reset'),
    ).resolves.toBeUndefined();

    expect(prisma.mailSendLog.count).toHaveBeenCalledWith({
      where: {
        email: 'user@example.com',
        flow: 'password_reset',
        sentAt: { gte: expect.any(Date) },
      },
    });
  });

  it('blocks send when quota reached', async () => {
    (prisma.mailSendLog.count as jest.Mock).mockResolvedValue(2);

    await expect(
      service.assertCanSend('user@example.com', 'password_reset'),
    ).rejects.toMatchObject({
      status: HttpStatus.TOO_MANY_REQUESTS,
    });
  });

  it('records a send with normalized email', async () => {
    await service.recordSend({
      email: ' User@Example.com ',
      flow: 'welcome',
      userId: 'user-id',
    });

    expect(prisma.mailSendLog.create).toHaveBeenCalledWith({
      data: {
        email: 'user@example.com',
        flow: 'welcome',
        userId: 'user-id',
      },
    });
  });
});
