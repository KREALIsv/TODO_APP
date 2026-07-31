import { GoneException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PairingStatus } from '@prisma/client';
import { AuthService } from '../auth/auth.service';
import { PrismaService } from '../common/services';
import { PairingService } from './pairing.service';

describe('PairingService', () => {
  const prisma = {
    pairingSession: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
  } as unknown as PrismaService;

  const auth = {
    issueSession: jest.fn(),
  } as unknown as AuthService;

  const config = {
    get: jest.fn(() => 'https://api.wodo.app'),
  } as unknown as ConfigService;

  let service: PairingService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PairingService(config, prisma, auth);
    (prisma.pairingSession.findFirst as jest.Mock).mockResolvedValue(null);
  });

  it('starts a pairing session with QR payload and poll token', async () => {
    (prisma.pairingSession.create as jest.Mock).mockImplementation(
      async ({ data }) => ({
        id: 'pair-1',
        ...data,
      }),
    );

    const result = await service.start({
      appUserId: 'device-1',
      clientPlatform: 'web',
    });

    expect(result.pairingId).toBe('pair-1');
    expect(result.displayCode).toHaveLength(8);
    expect(result.pollToken).toHaveLength(64);
    expect(result.qrPayload).toMatchObject({
      v: 1,
      pairingId: 'pair-1',
      code: result.displayCode,
      apiBase: 'https://api.wodo.app/api/v1',
    });
    expect(prisma.pairingSession.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        clientPlatform: 'web',
        newAppUserId: 'device-1',
        displayCode: result.displayCode,
      }),
    });
  });

  it('approves a pending pairing and stores a one-time session grant', async () => {
    const expiresAt = new Date(Date.now() + 60_000);
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue({
      id: 'pair-1',
      status: PairingStatus.pending,
      expiresAt,
      clientPlatform: 'web',
    });
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
    });
    (auth.issueSession as jest.Mock).mockResolvedValue({
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
    });
    (prisma.pairingSession.update as jest.Mock).mockResolvedValue({});

    await expect(
      service.approve('user-1', { pairingId: 'pair-1' }),
    ).resolves.toEqual({ accepted: true });

    expect(auth.issueSession).toHaveBeenCalledWith('user-1', 'web');
    expect(prisma.pairingSession.update).toHaveBeenCalledWith({
      where: { id: 'pair-1' },
      data: expect.objectContaining({
        status: PairingStatus.approved,
        grantAccessToken: 'access',
        grantEmail: 'user@example.com',
      }),
    });
  });

  it('poll returns pending until approved, then consumes grant', async () => {
    const pollToken = 'a'.repeat(64);
    (prisma.pairingSession.findUnique as jest.Mock)
      .mockResolvedValueOnce({
        id: 'pair-1',
        status: PairingStatus.pending,
        expiresAt: new Date(Date.now() + 60_000),
      })
      .mockResolvedValueOnce({
        id: 'pair-1',
        status: PairingStatus.approved,
        expiresAt: new Date(Date.now() + 60_000),
        grantAccessToken: 'access',
        grantRefreshToken: 'refresh',
        grantExpiresIn: 900,
        grantEmail: 'user@example.com',
      });
    (prisma.pairingSession.update as jest.Mock).mockResolvedValue({});

    await expect(service.poll(pollToken)).resolves.toEqual({
      status: 'pending',
    });

    await expect(service.poll(pollToken)).resolves.toEqual({
      status: 'approved',
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      email: 'user@example.com',
    });

    expect(prisma.pairingSession.update).toHaveBeenCalledWith({
      where: { id: 'pair-1' },
      data: expect.objectContaining({
        status: PairingStatus.consumed,
        grantAccessToken: null,
      }),
    });
  });

  it('rejects unknown poll tokens', async () => {
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue(null);
    await expect(service.poll('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('marks expired pending sessions on poll', async () => {
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue({
      id: 'pair-1',
      status: PairingStatus.pending,
      expiresAt: new Date(Date.now() - 1000),
    });
    (prisma.pairingSession.update as jest.Mock).mockResolvedValue({});

    await expect(service.poll('token')).resolves.toEqual({ status: 'expired' });
    expect(prisma.pairingSession.update).toHaveBeenCalledWith({
      where: { id: 'pair-1' },
      data: { status: PairingStatus.expired },
    });
  });

  it('rejects consumed sessions', async () => {
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue({
      id: 'pair-1',
      status: PairingStatus.consumed,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await expect(service.poll('token')).rejects.toBeInstanceOf(GoneException);
  });
});
