ALTER TABLE "subscriptions"
ADD COLUMN "provider" VARCHAR(32),
ADD COLUMN "provider_customer_id" VARCHAR(128),
ADD COLUMN "provider_subscription_id" VARCHAR(128),
ADD COLUMN "plan_id" VARCHAR(64),
ADD COLUMN "cancel_at_period_end" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "billing_events"
ADD COLUMN "provider" VARCHAR(32) NOT NULL DEFAULT 'revenuecat';

CREATE UNIQUE INDEX "subscriptions_provider_provider_subscription_id_key"
ON "subscriptions"("provider", "provider_subscription_id");

CREATE INDEX "billing_events_provider_event_id_idx"
ON "billing_events"("provider", "event_id");
