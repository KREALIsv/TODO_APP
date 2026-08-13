import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../common/services';
import { MailService } from '../mail';
import { EnableEncryptionDto, RegenerateRecoveryDto } from './dto';

@Injectable()
export class EncryptionService {
  private readonly logger = new Logger(EncryptionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
    private readonly config: ConfigService,
  ) {}

  async getSecurity(userId: string, appUserId?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado.');

    if (user.encryptionEnabled) {
      // Idempotent cleanup for accounts that enabled E2EE before purge shipped.
      void this.purgeLegacyPlaintext(userId).catch((error) => {
        this.logger.warn(`Legacy purge skipped for ${userId}: ${error}`);
      });
    }

    const devices = await this.prisma.device.findMany({
      where: { userId },
      orderBy: { lastSyncedAt: 'desc' },
    });

    const thisDevice = appUserId
      ? devices.find((d) => d.appUserId === appUserId)
      : undefined;

    return {
      encryptionEnabled: user.encryptionEnabled,
      encryptionVersion: user.encryptionVersion,
      hasRecovery: Boolean(user.encryptedDekRecovery && user.dekSalt),
      deviceVaultState: thisDevice?.vaultState ?? 'none',
      deviceTrusted: thisDevice?.trusted ?? false,
      devices: devices.map((d) => ({
        appUserId: d.appUserId,
        platform: d.platform,
        trusted: d.trusted,
        vaultState: d.vaultState,
        lastSyncedAt: d.lastSyncedAt?.toISOString() ?? null,
        pairedAt: d.pairedAt?.toISOString() ?? null,
        isThisDevice: appUserId != null && d.appUserId === appUserId,
      })),
    };
  }

  async enable(userId: string, dto: EnableEncryptionDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado.');
    if (user.encryptionEnabled) {
      throw new ConflictException('La protección ya está activada.');
    }

    const version = dto.encryptionVersion ?? 1;
    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          encryptionEnabled: true,
          encryptionVersion: version,
          dekSalt: dto.dekSalt.trim(),
          encryptedDekRecovery: dto.encryptedDekRecovery.trim(),
          recoveryHint: dto.recoveryHint?.trim() || null,
        },
      });

      await tx.device.upsert({
        where: { appUserId: dto.appUserId },
        create: {
          userId,
          appUserId: dto.appUserId,
          trusted: true,
          vaultState: 'trusted',
          pairedAt: now,
          lastSyncedAt: now,
        },
        update: {
          userId,
          trusted: true,
          vaultState: 'trusted',
          pairedAt: now,
          lastSyncedAt: now,
        },
      });
    });

    const purge = await this.purgeLegacyPlaintext(userId);

    return {
      encryptionEnabled: true,
      encryptionVersion: version,
      purgedMutations: purge.purgedMutations,
    };
  }

  /**
   * Deletes non-opaque sync mutations and blanks projected plaintext mirrors.
   * Safe to call repeatedly for E2EE accounts.
   */
  async purgeLegacyPlaintext(userId: string): Promise<{ purgedMutations: number }> {
    const rows = await this.prisma.syncMutation.findMany({
      where: { userId },
      select: { id: true, payload: true },
    });

    const legacyIds = rows
      .filter((row) => !this.isOpaquePayload(row.payload))
      .map((row) => row.id);

    if (legacyIds.length > 0) {
      await this.prisma.syncMutation.deleteMany({
        where: { id: { in: legacyIds } },
      });
    }

    await this.prisma.note.updateMany({
      where: { userId },
      data: {
        content: '',
        tagIds: [],
      },
    });

    await this.prisma.tag.updateMany({
      where: { userId },
      data: {
        name: '·',
      },
    });

    await this.prisma.dayEntry.updateMany({
      where: { userId },
      data: {
        outcome: null,
      },
    });

    return { purgedMutations: legacyIds.length };
  }

  /**
   * Returns the recovery wrap blob. The recovery code never leaves the client;
   * the client unwraps DEK locally with KDF(code, salt).
   */
  async getRecoveryWrap(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado.');
    if (!user.encryptionEnabled) {
      throw new BadRequestException('La protección no está activada.');
    }
    if (!user.encryptedDekRecovery || !user.dekSalt) {
      throw new NotFoundException('No hay código de recuperación en esta cuenta.');
    }

    return {
      dekSalt: user.dekSalt,
      encryptedDekRecovery: user.encryptedDekRecovery,
      encryptionVersion: user.encryptionVersion,
      recoveryHint: user.recoveryHint,
    };
  }

  /**
   * Replaces the recovery wrap with a new salt + ciphertext. Requires a trusted
   * device; the previous recovery code stops working immediately.
   */
  async regenerateRecoveryWrap(
    userId: string,
    dto: RegenerateRecoveryDto,
  ): Promise<{ regenerated: true }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado.');
    if (!user.encryptionEnabled) {
      throw new BadRequestException('La protección no está activada.');
    }

    const device = await this.prisma.device.findUnique({
      where: { appUserId: dto.appUserId.trim() },
    });
    if (!device || device.userId !== userId) {
      throw new ForbiddenException(
        'Este dispositivo no puede regenerar el código de recuperación.',
      );
    }
    if (!device.trusted || device.vaultState === 'revoked') {
      throw new ForbiddenException(
        'Solo un dispositivo vinculado puede regenerar el código.',
      );
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        dekSalt: dto.dekSalt.trim(),
        encryptedDekRecovery: dto.encryptedDekRecovery.trim(),
        recoveryHint: dto.recoveryHint?.trim() || user.recoveryHint,
      },
    });

    return { regenerated: true };
  }

  async markDeviceTrusted(userId: string, appUserId: string): Promise<void> {
    const now = new Date();
    await this.prisma.device.upsert({
      where: { appUserId },
      create: {
        userId,
        appUserId,
        trusted: true,
        vaultState: 'trusted',
        pairedAt: now,
        lastSyncedAt: now,
      },
      update: {
        userId,
        trusted: true,
        vaultState: 'trusted',
        pairedAt: now,
        lastSyncedAt: now,
      },
    });
  }

  /**
   * Relays the recovery code to the account email via Resend.
   * The code is NOT stored on the server — only logged as a send in mail_send_logs.
   */
  async sendRecoveryCodeEmail(
    userId: string,
    recoveryCode: string,
  ): Promise<{ accepted: true; skipped?: boolean }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return { accepted: true };
    }

    if (!this.mail.isConfigured()) {
      return { accepted: true, skipped: true };
    }

    const appUrl = this.config.get<string>(
      'WODO_APP_URL',
      'https://app.wodo.app',
    );
    const code = recoveryCode.trim();

    await this.mail.send({
      to: user.email,
      flow: 'vault_recovery',
      userId: user.id,
      subject: 'Tu código de recuperación de WODO',
      html: this.mail.buildVaultRecoveryCodeHtml(code, appUrl),
    });

    return { accepted: true };
  }

  private isOpaquePayload(payload: Prisma.JsonValue | null): boolean {
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return false;
    }
    const map = payload as Record<string, unknown>;
    return (
      map.v === 1 &&
      typeof map.alg === 'string' &&
      typeof map.nonce === 'string' &&
      typeof map.ciphertext === 'string'
    );
  }
}
