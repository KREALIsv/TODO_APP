import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class StartPairingDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  appUserId?: string;

  @IsOptional()
  @IsIn(['web', 'mobile'])
  clientPlatform?: 'web' | 'mobile';
}
