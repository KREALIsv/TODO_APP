import { ConflictException } from '@nestjs/common';
import { EncryptionService } from './encryption.service';
import { PrismaService } from '../common/services';

describe('EncryptionService', () => {
  const prisma = {
    user: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    device: {
      findMany: jest.fn(),
      upsert: jest.fn(),
    },
    $transaction: jest.fn(),
  } as unknown as PrismaService;

  let service: EncryptionService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new EncryptionService(prisma);
    (prisma.$transaction as jest.Mock).mockImplementation(
      async (fn: (tx: typeof prisma) => Promise<unknown>) => fn(prisma),
    );
  });

  it('enables encryption and marks device trusted', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      encryptionEnabled: false,
    });
    (prisma.user.update as jest.Mock).mockResolvedValue({});
    (prisma.device.upsert as jest.Mock).mockResolvedValue({});

    const result = await service.enable('user-1', {
      appUserId: 'device-1',
      dekSalt: 'salt-base64-value-xx',
      encryptedDekRecovery: 'wrap-blob-base64-value-xxxxxxxxxx',
      encryptionVersion: 1,
    });

    expect(result).toEqual({ encryptionEnabled: true, encryptionVersion: 1 });
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'user-1' },
      data: expect.objectContaining({
        encryptionEnabled: true,
        dekSalt: 'salt-base64-value-xx',
      }),
    });
    expect(prisma.device.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { appUserId: 'device-1' },
        create: expect.objectContaining({
          trusted: true,
          vaultState: 'trusted',
        }),
      }),
    );
  });

  it('rejects enabling twice', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      encryptionEnabled: true,
    });

    await expect(
      service.enable('user-1', {
        appUserId: 'device-1',
        dekSalt: 'salt-base64-value-xx',
        encryptedDekRecovery: 'wrap-blob-base64-value-xxxxxxxxxx',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('returns recovery wrap without requiring the code', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      encryptionEnabled: true,
      dekSalt: 'salt',
      encryptedDekRecovery: 'wrap',
      encryptionVersion: 1,
      recoveryHint: null,
    });

    await expect(service.getRecoveryWrap('user-1')).resolves.toEqual({
      dekSalt: 'salt',
      encryptedDekRecovery: 'wrap',
      encryptionVersion: 1,
      recoveryHint: null,
    });
  });
});
