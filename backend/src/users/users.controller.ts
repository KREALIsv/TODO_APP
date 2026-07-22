import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { UserDto } from './dto';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async me(@CurrentUser() user: CurrentUserPayload): Promise<UserDto> {
    const profile = await this.usersService.findById(user.userId);
    if (!profile) {
      throw new Error('User not found');
    }
    return profile;
  }

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteMe(@CurrentUser() user: CurrentUserPayload): Promise<void> {
    await this.usersService.deleteUser(user.userId);
  }
}
