import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { EnableEncryptionDto, RegenerateRecoveryDto, SendRecoveryCodeEmailDto } from './dto';
import { EncryptionService } from './encryption.service';

@Controller()
@UseGuards(AuthGuard)
export class EncryptionController {
  constructor(private readonly encryptionService: EncryptionService) {}

  @Get('users/me/security')
  getSecurity(
    @CurrentUser() user: CurrentUserPayload,
    @Query('appUserId') appUserId?: string,
  ) {
    return this.encryptionService.getSecurity(user.userId, appUserId);
  }

  @Post('encryption/enable')
  @HttpCode(HttpStatus.OK)
  enable(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: EnableEncryptionDto,
  ) {
    return this.encryptionService.enable(user.userId, dto);
  }

  @Get('encryption/recovery/wrap')
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 20, ttl: 900000 } })
  getRecoveryWrap(@CurrentUser() user: CurrentUserPayload) {
    return this.encryptionService.getRecoveryWrap(user.userId);
  }

  @Post('encryption/recovery/regenerate')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 5, ttl: 900000 } })
  regenerateRecoveryWrap(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: RegenerateRecoveryDto,
  ) {
    return this.encryptionService.regenerateRecoveryWrap(user.userId, dto);
  }

  @Post('encryption/recovery-code/email')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 5, ttl: 900000 } })
  sendRecoveryCodeEmail(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: SendRecoveryCodeEmailDto,
  ) {
    return this.encryptionService.sendRecoveryCodeEmail(
      user.userId,
      dto.recoveryCode,
    );
  }
}
