import { ConfigService } from '@nestjs/config';
import { EncryptionService } from './encryption.service';
import { PrismaService } from '../common/services';
import { MailService } from '../mail';

describe('EncryptionService', () => {
  const prisma = {
    user: {
      findUnique: jest.fn(),
    },
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
    service = new EncryptionService(config, prisma, mail);
  });

  it('skips send when mail is not configured', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
    });
    (mail.isConfigured as jest.Mock).mockReturnValue(false);

    const result = await service.sendRecoveryCodeEmail(
      'user-1',
      'recovery-code-abc',
    );

    expect(result).toEqual({ accepted: true, skipped: true });
    expect(mail.send).not.toHaveBeenCalled();
  });

  it('sends recovery code email without persisting the code', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
    });
    (mail.isConfigured as jest.Mock).mockReturnValue(true);
    (mail.buildVaultRecoveryCodeHtml as jest.Mock).mockReturnValue('<html>');
    (mail.send as jest.Mock).mockResolvedValue({ id: 'email-id' });

    const result = await service.sendRecoveryCodeEmail(
      'user-1',
      '  recovery-code-abc  ',
    );

    expect(result).toEqual({ accepted: true });
    expect(mail.buildVaultRecoveryCodeHtml).toHaveBeenCalledWith(
      'recovery-code-abc',
      'https://app.wodo.app',
    );
    expect(mail.send).toHaveBeenCalledWith({
      to: 'user@example.com',
      flow: 'vault_recovery',
      userId: 'user-1',
      subject: 'Tu código de recuperación de WODO',
      html: '<html>',
    });
  });
});
