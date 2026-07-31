import { IsOptional, IsString, MaxLength, MinLength, ValidateIf } from 'class-validator';

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
}
