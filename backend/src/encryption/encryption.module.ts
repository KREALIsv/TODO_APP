import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { MailModule } from '../mail';
import { EncryptionController } from './encryption.controller';
import { EncryptionService } from './encryption.service';

@Module({
  imports: [MailModule],
  controllers: [EncryptionController],
  providers: [EncryptionService, PrismaService],
  exports: [EncryptionService],
})
export class EncryptionModule {}
