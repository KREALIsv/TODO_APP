import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser, CurrentUserPayload } from '../common';
import { BillingService } from './billing.service';
import { CheckoutDto } from './dto/checkout.dto';

@Controller('billing')
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  @Get('plans')
  plans() {
    return this.billingService.getPlans();
  }

  @Get('me')
  @UseGuards(AuthGuard)
  me(@CurrentUser() user: CurrentUserPayload) {
    return this.billingService.getAccountPlan(user.userId);
  }

  @Post('checkout')
  @UseGuards(AuthGuard)
  checkout(
    @CurrentUser() user: CurrentUserPayload,
    @Body() input: CheckoutDto,
  ) {
    return this.billingService.createCheckoutIntent(user.userId, input.planId);
  }

  @Post('restore')
  @UseGuards(AuthGuard)
  restore(@CurrentUser() user: CurrentUserPayload) {
    return this.billingService.restore(user.userId);
  }
}
