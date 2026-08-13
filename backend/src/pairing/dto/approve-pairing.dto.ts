import {
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class ApprovePairingDto {
  @ValidateIf((o: ApprovePairingDto) => !o.code)
  @IsString()
  @MinLength(8)
  @MaxLength(64)
  pairingId?: string;

  @ValidateIf((o: ApprovePairingDto) => !o.pairingId)
  @IsString()
  @MinLength(4)
  @MaxLength(16)
  code?: string;

  /** Opaque AES-GCM envelope of DEK wrapped with ECDH shared secret. */
  @IsOptional()
  @IsString()
  @MinLength(32)
  @MaxLength(8192)
  wrappedDek?: string;

  /** Approver X25519 public key (base64) for the new device to derive the shared secret. */
  @IsOptional()
  @IsString()
  @MinLength(32)
  @MaxLength(256)
  approverEphemeralPub?: string;
}
