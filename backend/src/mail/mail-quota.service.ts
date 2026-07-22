import {
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MailFlow } from '@prisma/client';
import { PrismaService } from '../common/services';
import { MailFlowName } from './mail.types';

@Injectable()
export class MailQuotaService {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async assertCanSend(email: string, flow: MailFlowName): Promise<void> {
    const max = Number(this.config.get('MAIL_MAX_PER_USER_FLOW', 2));
    const windowHours = Number(this.config.get('MAIL_FLOW_WINDOW_HOURS', 24));
    const since = new Date(Date.now() - windowHours * 3600 * 1000);
    const normalized = email.trim().toLowerCase();

    const count = await this.prisma.mailSendLog.count({
      where: {
        email: normalized,
        flow: flow as MailFlow,
        sentAt: { gte: since },
      },
    });

    if (count >= max) {
      throw new HttpException(
        'Has alcanzado el límite de correos para este proceso. Inténtalo más tarde.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  async recordSend(params: {
    email: string;
    flow: MailFlowName;
    userId?: string;
  }): Promise<void> {
    await this.prisma.mailSendLog.create({
      data: {
        email: params.email.trim().toLowerCase(),
        flow: params.flow as MailFlow,
        userId: params.userId,
      },
    });
  }
}
