-- AlterTable users
ALTER TABLE "users" ADD COLUMN "encryption_enabled" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "encryption_version" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "users" ADD COLUMN "encrypted_dek_recovery" TEXT;
ALTER TABLE "users" ADD COLUMN "dek_salt" VARCHAR(128);
ALTER TABLE "users" ADD COLUMN "recovery_hint" VARCHAR(64);

-- AlterTable devices
ALTER TABLE "devices" ADD COLUMN "trusted" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "devices" ADD COLUMN "vault_state" VARCHAR(16) NOT NULL DEFAULT 'none';
ALTER TABLE "devices" ADD COLUMN "paired_at" TIMESTAMPTZ(6);

-- AlterTable pairing_sessions
ALTER TABLE "pairing_sessions" ADD COLUMN "ephemeral_pub" TEXT;
ALTER TABLE "pairing_sessions" ADD COLUMN "grant_wrapped_dek" TEXT;
ALTER TABLE "pairing_sessions" ADD COLUMN "grant_approver_pub" TEXT;
