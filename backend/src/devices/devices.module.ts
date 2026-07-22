import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { DevicesService } from './devices.service';

@Module({
  providers: [DevicesService, PrismaService],
  exports: [DevicesService],
})
export class DevicesModule {}
