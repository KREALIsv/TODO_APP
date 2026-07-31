import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../common/services';
import { MailService } from '../mail';

@Injectable()
export class EncryptionService {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
  ) {}

  async sendRecoveryCodeEmail(
    userId: string,
    recoveryCode: string,
  ): Promise<{ accepted: true; skipped?: boolean }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      return { accepted: true };
    }

    if (!this.mail.isConfigured()) {
      return { accepted: true, skipped: true };
    }

    const appUrl = this.config.get<string>(
      'WODO_APP_URL',
      'https://app.wodo.app',
    );
    const code = recoveryCode.trim();

    await this.mail.send({
      to: user.email,
      flow: 'vault_recovery',
      userId: user.id,
      subject: 'Tu código de recuperación de WODO',
      html: this.mail.buildVaultRecoveryCodeHtml(code, appUrl),
    });

    return { accepted: true };
  }
}
