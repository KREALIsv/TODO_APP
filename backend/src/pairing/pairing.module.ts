import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { DevicesModule } from '../devices/devices.module';
import { PrismaService } from '../common/services';
import { PairingController } from './pairing.controller';
import { PairingService } from './pairing.service';

@Module({
  imports: [AuthModule, DevicesModule],
  controllers: [PairingController],
  providers: [PairingService, PrismaService],
  exports: [PairingService],
})
export class PairingModule {}
