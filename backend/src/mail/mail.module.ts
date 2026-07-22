import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { MailQuotaService } from './mail-quota.service';
import { MailService } from './mail.service';

@Module({
  providers: [MailService, MailQuotaService, PrismaService],
  exports: [MailService, MailQuotaService],
})
export class MailModule {}
