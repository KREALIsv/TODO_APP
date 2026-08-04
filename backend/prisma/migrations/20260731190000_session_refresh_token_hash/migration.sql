-- Invalidate existing sessions (refresh tokens move from plaintext to sha256 hash).
DELETE FROM "sessions";

-- Rename column and tighten length for hex sha256 (64 chars); keep headroom.
ALTER TABLE "sessions" RENAME COLUMN "refresh_token" TO "refresh_token_hash";
ALTER TABLE "sessions" ALTER COLUMN "refresh_token_hash" TYPE VARCHAR(128);

-- Keep unique constraint; rename indexes to match Prisma mapping.
ALTER INDEX IF EXISTS "sessions_refresh_token_key" RENAME TO "sessions_refresh_token_hash_key";
DROP INDEX IF EXISTS "sessions_refresh_token_idx";
CREATE INDEX "sessions_refresh_token_hash_idx" ON "sessions"("refresh_token_hash");
