import { IsOptional, IsString, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @MaxLength(64)
  appUserId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  platform?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  osVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  appVersion?: string;
}
