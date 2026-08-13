-- CreateEnum
CREATE TYPE "PairingStatus" AS ENUM ('pending', 'approved', 'consumed', 'expired');

-- CreateTable
CREATE TABLE "pairing_sessions" (
    "id" UUID NOT NULL,
    "display_code" VARCHAR(16) NOT NULL,
    "poll_token_hash" VARCHAR(128) NOT NULL,
    "status" "PairingStatus" NOT NULL DEFAULT 'pending',
    "client_platform" VARCHAR(16),
    "new_app_user_id" VARCHAR(64),
    "approver_user_id" UUID,
    "grant_access_token" TEXT,
    "grant_refresh_token" TEXT,
    "grant_expires_in" INTEGER,
    "grant_email" VARCHAR(255),
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "approved_at" TIMESTAMPTZ(6),
    "consumed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "pairing_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pairing_sessions_poll_token_hash_key" ON "pairing_sessions"("poll_token_hash");

-- CreateIndex
CREATE INDEX "pairing_sessions_display_code_idx" ON "pairing_sessions"("display_code");

-- CreateIndex
CREATE INDEX "pairing_sessions_status_expires_at_idx" ON "pairing_sessions"("status", "expires_at");

-- AddForeignKey
ALTER TABLE "pairing_sessions" ADD CONSTRAINT "pairing_sessions_approver_user_id_fkey" FOREIGN KEY ("approver_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
