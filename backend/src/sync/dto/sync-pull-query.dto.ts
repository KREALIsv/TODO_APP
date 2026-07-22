import { IsOptional, IsString } from 'class-validator';

export class SyncPullQueryDto {
  @IsString()
  @IsOptional()
  cursor?: string;

  @IsString()
  @IsOptional()
  entityType?: string;

  @IsString()
  @IsOptional()
  appUserId?: string;
}
