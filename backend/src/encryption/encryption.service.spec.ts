import { ConflictException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EncryptionService } from './encryption.service';
import { PrismaService } from '../common/services';
import { MailService } from '../mail';

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
    syncMutation: {
      findMany: jest.fn(),
      deleteMany: jest.fn(),
    },
    note: {
      updateMany: jest.fn(),
    },
    tag: {
      updateMany: jest.fn(),
    },
    dayEntry: {
      updateMany: jest.fn(),
    },
    $transaction: jest.fn(),
  } as unknown as PrismaService;

  const mail = {
    isConfigured: jest.fn(),
    send: jest.fn(),
    buildVaultRecoveryCodeHtml: jest.fn(),
  } as unknown as MailService;

  const config = {
    get: jest.fn((key: string, fallback?: unknown) => {
      if (key === 'WODO_APP_URL') return 'https://app.wodo.app';
      return fallback;
    }),
  } as unknown as ConfigService;

  let service: EncryptionService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new EncryptionService(prisma, mail, config);
    (prisma.$transaction as jest.Mock).mockImplementation(
      async (fn: (tx: typeof prisma) => Promise<unknown>) => fn(prisma),
    );
    (prisma.syncMutation.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.syncMutation.deleteMany as jest.Mock).mockResolvedValue({ count: 0 });
    (prisma.note.updateMany as jest.Mock).mockResolvedValue({ count: 0 });
    (prisma.tag.updateMany as jest.Mock).mockResolvedValue({ count: 0 });
    (prisma.dayEntry.updateMany as jest.Mock).mockResolvedValue({ count: 0 });
  });

  it('enables encryption, marks device trusted, and purges legacy plaintext', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      encryptionEnabled: false,
    });
    (prisma.user.update as jest.Mock).mockResolvedValue({});
    (prisma.device.upsert as jest.Mock).mockResolvedValue({});
    (prisma.syncMutation.findMany as jest.Mock).mockResolvedValue([
      { id: 'm1', payload: { title: 'secreto' } },
      {
        id: 'm2',
        payload: {
          v: 1,
          alg: 'AES-256-GCM',
          nonce: 'n',
          ciphertext: 'c',
        },
      },
    ]);

    const result = await service.enable('user-1', {
      appUserId: 'device-1',
      dekSalt: 'salt-base64-value-xx',
      encryptedDekRecovery: 'wrap-blob-base64-value-xxxxxxxxxx',
      encryptionVersion: 1,
    });

    expect(result).toEqual({
      encryptionEnabled: true,
      encryptionVersion: 1,
      purgedMutations: 1,
    });
    expect(prisma.syncMutation.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['m1'] } },
    });
    expect(prisma.note.updateMany).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
      data: { content: '', tagIds: [] },
    });
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

  it('purgeLegacyPlaintext only deletes non-opaque mutations', async () => {
    (prisma.syncMutation.findMany as jest.Mock).mockResolvedValue([
      { id: 'plain', payload: { content: 'x' } },
      {
        id: 'opaque',
        payload: { v: 1, alg: 'AES-256-GCM', nonce: 'n', ciphertext: 'c' },
      },
    ]);

    await expect(service.purgeLegacyPlaintext('user-1')).resolves.toEqual({
      purgedMutations: 1,
    });
    expect(prisma.syncMutation.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['plain'] } },
    });
  });

  it('relays recovery code by email without persisting it', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
    });
    (mail.isConfigured as jest.Mock).mockReturnValue(true);
    (mail.buildVaultRecoveryCodeHtml as jest.Mock).mockReturnValue('<html>');
    (mail.send as jest.Mock).mockResolvedValue({ id: 'email-1' });

    await expect(
      service.sendRecoveryCodeEmail('user-1', '  ABCD-CODE  '),
    ).resolves.toEqual({ accepted: true });

    expect(mail.send).toHaveBeenCalledWith({
      to: 'user@example.com',
      flow: 'vault_recovery',
      userId: 'user-1',
      subject: 'Tu código de recuperación de WODO',
      html: '<html>',
    });
    expect(mail.buildVaultRecoveryCodeHtml).toHaveBeenCalledWith(
      'ABCD-CODE',
      'https://app.wodo.app',
    );
  });

  it('skips recovery email when Resend is not configured', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
    });
    (mail.isConfigured as jest.Mock).mockReturnValue(false);

    await expect(
      service.sendRecoveryCodeEmail('user-1', 'ABCD-CODE'),
    ).resolves.toEqual({ accepted: true, skipped: true });
    expect(mail.send).not.toHaveBeenCalled();
  });
});
