import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { ApprovePairingDto, StartPairingDto } from './dto';
import {
  PairingPollResult,
  PairingService,
  PairingStartResult,
} from './pairing.service';

@Controller('pairing')
export class PairingController {
  constructor(private readonly pairingService: PairingService) {}

  @Post('start')
  @HttpCode(HttpStatus.CREATED)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 20, ttl: 900000 } })
  start(@Body() dto: StartPairingDto): Promise<PairingStartResult> {
    return this.pairingService.start(dto);
  }

  @Post('approve')
  @HttpCode(HttpStatus.OK)
  @UseGuards(AuthGuard, ThrottlerGuard)
  @Throttle({ default: { limit: 30, ttl: 900000 } })
  approve(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: ApprovePairingDto,
  ): Promise<{ accepted: true }> {
    return this.pairingService.approve(user.userId, dto);
  }

  @Get('poll')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 120, ttl: 900000 } })
  poll(
    @Headers('x-pairing-token') headerToken?: string,
    @Query('token') queryToken?: string,
  ): Promise<PairingPollResult> {
    const token = headerToken?.trim() || queryToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Token de vinculación requerido.');
    }
    return this.pairingService.poll(token);
  }
}
