import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { SyncPullQueryDto, SyncPushDto } from './dto';
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(AuthGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  push(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: SyncPushDto,
  ): Promise<{ accepted: number; revision: string }> {
    return this.syncService.push(user.userId, dto.mutations);
  }

  @Get('pull')
  pull(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: SyncPullQueryDto,
  ) {
    return this.syncService.pull(
      user.userId,
      query.cursor,
      query.entityType,
    );
  }

  @Get('status')
  status(@CurrentUser() user: CurrentUserPayload) {
    return this.syncService.status(user.userId);
  }
}
