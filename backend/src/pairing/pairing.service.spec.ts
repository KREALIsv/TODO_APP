import { BadRequestException, GoneException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PairingStatus } from '@prisma/client';
import { AuthService } from '../auth/auth.service';
import { DevicesService } from '../devices/devices.service';
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

  const devices = {
    markTrusted: jest.fn(),
  } as unknown as DevicesService;

  const config = {
    get: jest.fn(() => 'https://api.wodo.app'),
  } as unknown as ConfigService;

  let service: PairingService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PairingService(config, prisma, auth, devices);
    (prisma.pairingSession.findFirst as jest.Mock).mockResolvedValue(null);
  });

  it('starts a pairing session with ephemeral pub in QR', async () => {
    (prisma.pairingSession.create as jest.Mock).mockImplementation(
      async ({ data }) => ({
        id: 'pair-1',
        ...data,
      }),
    );

    const result = await service.start({
      appUserId: 'device-1',
      clientPlatform: 'web',
      ephemeralPub: 'pub-key-base64-xxxxxxxxxxxxxxxxxxxx',
    });

    expect(result.qrPayload.ephemeralPub).toBe(
      'pub-key-base64-xxxxxxxxxxxxxxxxxxxx',
    );
    expect(prisma.pairingSession.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        ephemeralPub: 'pub-key-base64-xxxxxxxxxxxxxxxxxxxx',
      }),
    });
  });

  it('requires wrapped DEK when account has encryption enabled', async () => {
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue({
      id: 'pair-1',
      status: PairingStatus.pending,
      expiresAt: new Date(Date.now() + 60_000),
      clientPlatform: 'web',
      newAppUserId: 'device-new',
    });
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      encryptionEnabled: true,
    });

    await expect(
      service.approve('user-1', { pairingId: 'pair-1' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('stores wrapped DEK grant and marks new device trusted', async () => {
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue({
      id: 'pair-1',
      status: PairingStatus.pending,
      expiresAt: new Date(Date.now() + 60_000),
      clientPlatform: 'web',
      newAppUserId: 'device-new',
    });
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      encryptionEnabled: true,
    });
    (auth.issueSession as jest.Mock).mockResolvedValue({
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
    });
    (prisma.pairingSession.update as jest.Mock).mockResolvedValue({});

    await service.approve('user-1', {
      pairingId: 'pair-1',
      wrappedDek: 'wrapped-dek-blob-xxxxxxxxxxxxxxxx',
      approverEphemeralPub: 'approver-pub-xxxxxxxxxxxxxxxxxxxx',
    });

    expect(prisma.pairingSession.update).toHaveBeenCalledWith({
      where: { id: 'pair-1' },
      data: expect.objectContaining({
        grantWrappedDek: 'wrapped-dek-blob-xxxxxxxxxxxxxxxx',
        grantApproverPub: 'approver-pub-xxxxxxxxxxxxxxxxxxxx',
      }),
    });
    expect(devices.markTrusted).toHaveBeenCalledWith('user-1', 'device-new');
  });

  it('poll returns wrapped DEK once then consumes', async () => {
    const pollToken = 'a'.repeat(64);
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue({
      id: 'pair-1',
      status: PairingStatus.approved,
      expiresAt: new Date(Date.now() + 60_000),
      grantAccessToken: 'access',
      grantRefreshToken: 'refresh',
      grantExpiresIn: 900,
      grantEmail: 'user@example.com',
      grantWrappedDek: 'wrap',
      grantApproverPub: 'pub',
      approverUserId: 'user-1',
    });
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      encryptionEnabled: true,
    });
    (prisma.pairingSession.update as jest.Mock).mockResolvedValue({});

    await expect(service.poll(pollToken)).resolves.toEqual({
      status: 'approved',
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      email: 'user@example.com',
      wrappedDek: 'wrap',
      approverEphemeralPub: 'pub',
      encryptionEnabled: true,
    });
  });

  it('rejects unknown poll tokens', async () => {
    (prisma.pairingSession.findUnique as jest.Mock).mockResolvedValue(null);
    await expect(service.poll('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
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
