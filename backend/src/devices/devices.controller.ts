import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { DevicesService } from './devices.service';

@Controller('devices')
@UseGuards(AuthGuard)
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Post('register')
  register(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.devicesService.registerOrUpdate(user.userId, dto.appUserId, {
      platform: dto.platform,
      osVersion: dto.osVersion,
      appVersion: dto.appVersion,
    });
  }

  @Get()
  list(@CurrentUser() user: CurrentUserPayload) {
    return this.devicesService.getByUser(user.userId);
  }

  @Delete(':appUserId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async revoke(
    @CurrentUser() user: CurrentUserPayload,
    @Param('appUserId') appUserId: string,
  ): Promise<void> {
    await this.devicesService.revoke(user.userId, appUserId);
  }
}
