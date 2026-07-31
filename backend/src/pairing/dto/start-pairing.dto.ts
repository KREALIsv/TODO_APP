import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class StartPairingDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  appUserId?: string;

  @IsOptional()
  @IsIn(['web', 'mobile'])
  clientPlatform?: 'web' | 'mobile';

  /** X25519 public key (base64) from the new device for DEK relay. */
  @IsOptional()
  @IsString()
  @MinLength(32)
  @MaxLength(256)
  ephemeralPub?: string;
}
