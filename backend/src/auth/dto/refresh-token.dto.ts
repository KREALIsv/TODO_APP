import { IsIn, IsOptional, IsString } from 'class-validator';

export class RefreshTokenDto {
  @IsString()
  refreshToken!: string;

  @IsOptional()
  @IsIn(['web', 'mobile'])
  clientPlatform?: 'web' | 'mobile';
}
