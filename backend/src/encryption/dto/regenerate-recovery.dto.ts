import {
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RegenerateRecoveryDto {
  @IsString()
  @MinLength(8)
  @MaxLength(64)
  appUserId!: string;

  @IsString()
  @MinLength(16)
  @MaxLength(128)
  dekSalt!: string;

  @IsString()
  @MinLength(32)
  @MaxLength(8192)
  encryptedDekRecovery!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  recoveryHint?: string;
}
