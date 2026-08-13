import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class EnableEncryptionDto {
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
  @IsInt()
  @Min(1)
  @Max(100)
  encryptionVersion?: number;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  recoveryHint?: string;
}
