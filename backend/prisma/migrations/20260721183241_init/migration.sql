-- CreateEnum
CREATE TYPE "AuthProvider" AS ENUM ('email', 'google', 'apple');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password_hash" VARCHAR(255),
    "email_verified" BOOLEAN NOT NULL DEFAULT false,
    "is_admin" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_identities" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "provider" "AuthProvider" NOT NULL,
    "provider_id" VARCHAR(255) NOT NULL,
    "email" VARCHAR(255),
    "display_name" VARCHAR(255),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "user_identities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "refresh_token" VARCHAR(512) NOT NULL,
    "session_uuid" VARCHAR(64) NOT NULL,
    "ip_address" VARCHAR(45),
    "user_agent" TEXT,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "devices" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "app_user_id" VARCHAR(64) NOT NULL,
    "platform" VARCHAR(32),
    "os_version" VARCHAR(32),
    "app_version" VARCHAR(32),
    "last_synced_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notes" (
    "id" VARCHAR(64) NOT NULL,
    "user_id" UUID NOT NULL,
    "content" TEXT NOT NULL,
    "archived_at" TIMESTAMPTZ(6),
    "due_at" TIMESTAMPTZ(6),
    "reminder_offset" VARCHAR(16),
    "tag_ids" VARCHAR(64)[],
    "server_revision" BIGINT NOT NULL,
    "server_updated_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "notes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tags" (
    "id" VARCHAR(64) NOT NULL,
    "user_id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "color_id" VARCHAR(32),
    "opacity" DOUBLE PRECISION,
    "server_revision" BIGINT NOT NULL,
    "server_updated_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "tags_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "day_entries" (
    "id" VARCHAR(64) NOT NULL,
    "user_id" UUID NOT NULL,
    "note_id" VARCHAR(64) NOT NULL,
    "day" DATE NOT NULL,
    "outcome" VARCHAR(16),
    "server_revision" BIGINT NOT NULL,
    "server_updated_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "day_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_cursors" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "device_id" UUID,
    "entity_type" VARCHAR(32) NOT NULL,
    "server_revision" BIGINT NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "sync_cursors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_mutations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "device_id" UUID,
    "client_mutation_id" VARCHAR(128) NOT NULL,
    "entity_type" VARCHAR(32) NOT NULL,
    "entity_id" VARCHAR(64) NOT NULL,
    "operation" VARCHAR(16) NOT NULL,
    "payload" JSONB,
    "server_revision" BIGINT NOT NULL,
    "server_updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "applied_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "conflict_copy_id" VARCHAR(64),

    CONSTRAINT "sync_mutations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_email_idx" ON "users"("email");

-- CreateIndex
CREATE INDEX "user_identities_user_id_idx" ON "user_identities"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_identities_provider_provider_id_key" ON "user_identities"("provider", "provider_id");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_refresh_token_key" ON "sessions"("refresh_token");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_session_uuid_key" ON "sessions"("session_uuid");

-- CreateIndex
CREATE INDEX "sessions_user_id_idx" ON "sessions"("user_id");

-- CreateIndex
CREATE INDEX "sessions_refresh_token_idx" ON "sessions"("refresh_token");

-- CreateIndex
CREATE INDEX "sessions_expires_at_idx" ON "sessions"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "devices_app_user_id_key" ON "devices"("app_user_id");

-- CreateIndex
CREATE INDEX "devices_user_id_idx" ON "devices"("user_id");

-- CreateIndex
CREATE INDEX "devices_app_user_id_idx" ON "devices"("app_user_id");

-- CreateIndex
CREATE INDEX "notes_user_id_server_updated_at_idx" ON "notes"("user_id", "server_updated_at");

-- CreateIndex
CREATE INDEX "notes_user_id_server_revision_idx" ON "notes"("user_id", "server_revision");

-- CreateIndex
CREATE UNIQUE INDEX "notes_user_id_id_key" ON "notes"("user_id", "id");

-- CreateIndex
CREATE INDEX "tags_user_id_server_updated_at_idx" ON "tags"("user_id", "server_updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "tags_user_id_id_key" ON "tags"("user_id", "id");

-- CreateIndex
CREATE INDEX "day_entries_user_id_note_id_day_idx" ON "day_entries"("user_id", "note_id", "day");

-- CreateIndex
CREATE INDEX "day_entries_user_id_server_updated_at_idx" ON "day_entries"("user_id", "server_updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "day_entries_user_id_id_key" ON "day_entries"("user_id", "id");

-- CreateIndex
CREATE INDEX "sync_cursors_user_id_idx" ON "sync_cursors"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "sync_cursors_user_id_device_id_entity_type_key" ON "sync_cursors"("user_id", "device_id", "entity_type");

-- CreateIndex
CREATE INDEX "sync_mutations_user_id_server_updated_at_idx" ON "sync_mutations"("user_id", "server_updated_at");

-- CreateIndex
CREATE INDEX "sync_mutations_user_id_entity_type_entity_id_idx" ON "sync_mutations"("user_id", "entity_type", "entity_id");

-- CreateIndex
CREATE UNIQUE INDEX "sync_mutations_user_id_client_mutation_id_key" ON "sync_mutations"("user_id", "client_mutation_id");

-- AddForeignKey
ALTER TABLE "user_identities" ADD CONSTRAINT "user_identities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notes" ADD CONSTRAINT "notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tags" ADD CONSTRAINT "tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "day_entries" ADD CONSTRAINT "day_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_cursors" ADD CONSTRAINT "sync_cursors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
