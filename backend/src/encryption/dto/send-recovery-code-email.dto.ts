import { IsString, MaxLength, MinLength } from 'class-validator';

export class SendRecoveryCodeEmailDto {
  @IsString()
  @MinLength(8)
  @MaxLength(512)
  recoveryCode!: string;
}
