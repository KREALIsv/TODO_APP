import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../common/services';
import { EnableEncryptionDto } from './dto';

@Injectable()
export class EncryptionService {
  constructor(private readonly prisma: PrismaService) {}

  async getSecurity(userId: string, appUserId?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado.');

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

    return {
      encryptionEnabled: true,
      encryptionVersion: version,
    };
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
}
