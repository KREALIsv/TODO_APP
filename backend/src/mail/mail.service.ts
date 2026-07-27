import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MailQuotaService } from './mail-quota.service';
import { MailSendResult, SendMailParams } from './mail.types';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly quota: MailQuotaService,
  ) {}

  isConfigured(): boolean {
    const key = this.config.get<string>('RESEND_API_KEY');
    return Boolean(key && key.trim().length > 0);
  }

  async send(params: SendMailParams): Promise<MailSendResult> {
    const apiKey = this.config.get<string>('RESEND_API_KEY');
    const from = this.config.get<string>(
      'MAIL_FROM',
      'WODO <noreply@krealistudio.com>',
    );

    if (!apiKey?.trim()) {
      this.logger.warn(`Mail skipped (${params.flow}): RESEND_API_KEY not set`);
      return { skipped: true, reason: 'mail_not_configured' };
    }

    await this.quota.assertCanSend(params.to, params.flow);

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey.trim()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [params.to.trim().toLowerCase()],
        subject: params.subject,
        html: params.html,
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      this.logger.error(
        `Resend failed (${params.flow}) status=${response.status} body=${body}`,
      );
      throw new Error('No se pudo enviar el correo.');
    }

    const payload = (await response.json()) as { id?: string };
    await this.quota.recordSend({
      email: params.to,
      flow: params.flow,
      userId: params.userId,
    });

    return { id: payload.id };
  }

  buildPasswordResetHtml(resetUrl: string): string {
    return `
      <div style="font-family: system-ui, sans-serif; max-width: 480px; margin: 0 auto; color: #1a1a1a;">
        <p style="font-size: 18px; font-weight: 600;">Recuperar acceso a WODO</p>
        <p>Recibimos una solicitud para restablecer tu contraseña. Si fuiste tú, pulsa el botón:</p>
        <p style="margin: 28px 0;">
          <a href="${resetUrl}" style="background: #F2327D; color: #fff; text-decoration: none; padding: 12px 20px; border-radius: 10px; display: inline-block; font-weight: 600;">
            Nueva contraseña
          </a>
        </p>
        <p style="font-size: 14px; color: #555;">El enlace caduca en 1 hora. Si no pediste esto, ignora este correo.</p>
        <p style="font-size: 12px; color: #888;">WODO · Kreali Studio</p>
      </div>
    `.trim();
  }

  buildWelcomeHtml(appUrl: string): string {
    return `
      <div style="font-family: system-ui, sans-serif; max-width: 480px; margin: 0 auto; color: #1a1a1a;">
        <p style="font-size: 18px; font-weight: 600;">Bienvenida/o a WODO</p>
        <p>Tu cuenta está lista. Tus notas y tareas se sincronizan cuando inicias sesión en otros dispositivos.</p>
        <p style="margin: 28px 0;">
          <a href="${appUrl}" style="background: #F2327D; color: #fff; text-decoration: none; padding: 12px 20px; border-radius: 10px; display: inline-block; font-weight: 600;">
            Abrir WODO
          </a>
        </p>
        <p style="font-size: 12px; color: #888;">WODO · Kreali Studio</p>
      </div>
    `.trim();
  }
}
