import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { EncryptionController } from './encryption.controller';
import { EncryptionService } from './encryption.service';

@Module({
  controllers: [EncryptionController],
  providers: [EncryptionService, PrismaService],
  exports: [EncryptionService],
})
export class EncryptionModule {}
