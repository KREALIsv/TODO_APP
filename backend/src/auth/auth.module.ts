import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { MailModule } from '../mail';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  imports: [MailModule],
  controllers: [AuthController],
  providers: [AuthService, PrismaService],
  exports: [AuthService],
})
export class AuthModule {}
