import { IsIn, IsString } from 'class-validator';

export class CheckoutDto {
  @IsString()
  @IsIn(['wodo_plus_monthly', 'wodo_plus_annual'])
  planId!: string;
}
