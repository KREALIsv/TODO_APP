import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';

@Module({
  controllers: [SyncController],
  providers: [SyncService, PrismaService],
  exports: [SyncService],
})
export class SyncModule {}
