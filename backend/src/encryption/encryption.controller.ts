import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { SendRecoveryCodeEmailDto } from './dto';
import { EncryptionService } from './encryption.service';

@Controller('encryption')
@UseGuards(AuthGuard)
export class EncryptionController {
  constructor(private readonly encryptionService: EncryptionService) {}

  @Post('recovery-code/email')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 5, ttl: 900000 } })
  async sendRecoveryCodeEmail(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: SendRecoveryCodeEmailDto,
  ): Promise<{ accepted: true; skipped?: boolean }> {
    return this.encryptionService.sendRecoveryCodeEmail(
      user.userId,
      dto.recoveryCode,
    );
  }
}
